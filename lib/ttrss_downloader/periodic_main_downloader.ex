defmodule TTRSSDownloader.PeriodicMainDownloader do
  @moduledoc """
  """

  alias __MODULE__
  alias TTRSS.{Account, Article}
  alias TTRSSDownloader.Worker
  alias Util.DownloadTranscode

  require Logger

  def child_spec(init_args) do
    Supervisor.child_spec({__MODULE__.Sup, init_args}, id: __MODULE__)
  end

  defmodule Sup do
    @moduledoc """
    Supervisor for ArticleFetcher workers
    """
    use Supervisor

    def start_link(init_args) do
      Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
    end

    @impl true
    def init(interval: interval, accounts: accounts) do
      children =
        accounts
        |> Stream.with_index()
        |> Enum.map(fn {account, index} ->
          id = "#{PeriodicMainDownloader.ArticleFetcher}_#{index}"

          Supervisor.child_spec({PeriodicMainDownloader.ArticleFetcher, [interval: interval, account: account]},
            id: id
          )
        end)

      Supervisor.init(children, strategy: :one_for_one, max_restarts: 1_000, max_seconds: 300)
    end
  end

  defmodule ArticleFetcher do
    @moduledoc """
    Process that fetches the articles
    """
    use GenServer

    def start_link(init_args) do
      GenServer.start_link(__MODULE__, init_args)
    end

    @impl true
    def init(interval: interval, account: %Account{} = account) do
      Logger.info("Starting #{__MODULE__} account=#{account.username} timer=#{interval}")
      :timer.send_interval(interval, :tick)
      {:ok, account}
    end

    @impl true
    def handle_info(:tick, account) do
      GenServer.cast(self(), {:run_download})
      {:noreply, account}
    end

    @impl true
    def handle_cast({:run_download}, %Account{} = account) do
      Logger.info("Running downloader for account=#{account.username}")

      account = maybe_login(account)

      account
      |> get_unread_article_messages()
      |> Stream.filter(&Article.has_audio_attachment?/1)
      |> Stream.reject(&file_already_exists?/1)
      # TODO this needs to be a pool using distributed workers because a single timeout will cancel the other jobs
      |> Task.async_stream(&Worker.download_transcode/1, ordered: false, timeout: 3_600_000, max_concurrency: Worker.num_workers())
      |> Stream.filter(fn {stream_status, {worker_status, _value}} -> stream_status == :ok and worker_status == :ok end)
      |> Stream.map(fn {_stream_status, {_worker_status, value}} -> value end)
      |> Stream.map(&copy_to_destination/1)
      |> Enum.map(&mark_read/1)

      {:noreply, account}
    end

    defp get_unread_article_messages(%Account{} = account) do
      Logger.debug("Getting articles url=#{account.api_url} account=#{account.username}")
      {:ok, unread_articles} = TTRSS.Client.get_all_unread_articles(account.api_url, account.sid)

      Enum.map(unread_articles, &Article.new(&1, account))
    end

    defp file_already_exists?(%Article{} = article) do
      article
      |> Article.construct_output_file_path()
      |> File.exists?()
    end

    defp copy_to_destination(%Article{} = article) do
      destination = Article.construct_output_file_path(article)

      :ok = File.mkdir_p(Path.dirname(destination))

      if article.saved_node != Node.self() do
        Logger.info("Article downloaded on remote node #{article.saved_node} transferring to #{Node.self()}")
        DownloadTranscode.get_remote_file(article.saved_node, article.saved_path, destination)
      else
        Logger.info("Copying #{article.saved_path} to #{destination}")
        File.copy(article.saved_path, destination)
      end

      article
    end

    defp mark_read(%Article{article: article, account: account}) do
      TTRSS.Client.mark_article_read(article, account.api_url, account.sid)
    end

    defp maybe_login(%Account{sid: sid} = account) when is_nil(sid), do: Account.login(account)
    defp maybe_login(account), do: account

    def bind({:ok, value}, function), do: function.(value)
    def bind({:error, reason}, _function), do: {:error, reason}
  end
end
