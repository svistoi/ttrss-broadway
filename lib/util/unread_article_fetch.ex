defmodule Util.UnreadArticleFetch do
  @moduledoc """
  A periodic tasks to get articles from tt-rss and add them to the Broadway
  Pipeline
  """
  require Logger
  alias TTRSS.Account
  alias Broadway.ArticleMessage

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
          id = "#{Util.UnreadArticleFetch.ArticleFetcher}_#{index}"

          Supervisor.child_spec({Util.UnreadArticleFetch.ArticleFetcher, [interval: interval, account: account]},
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
      GenServer.cast(self(), {:update})
      {:noreply, account}
    end

    @impl true
    def handle_cast({:update}, %Account{} = account) do
      Logger.debug("Cron job looking up unread articles")

      account =
        if is_nil(account.sid) do
          Account.login(account)
        else
          account
        end

      unread_articles = get_unread_article_messages(account)

      producer_name =
        Broadway.producer_names(Broadway.DownloadPipeline)
        |> Enum.random()

      Logger.info(
        "Pushing articles=#{length(unread_articles)} account=#{account.username} producer=#{inspect(producer_name)}"
      )

      GenStage.cast(producer_name, {:notify, unread_articles})

      {:noreply, account}
    end

    # Fetches article given account and returns them via
    defp get_unread_article_messages(%Account{} = account) do
      Logger.debug("Getting articles url=#{account.api_url} account=#{account.username}")
      {:ok, unread_articles} = TTRSS.Client.get_all_unread_articles(account.api_url, account.sid)

      unread_articles
      |> Enum.map(&ArticleMessage.new(&1, account))
    end
  end
end
