defmodule Util.UnreadArticleFetch do
  @moduledoc """
  A periodic tasks to get articles from tt-rss and add them to the Broadway
  Pipeline
  """
  require Logger
  alias TTRSS.Account
  alias Broadway.ArticleMessage

  @defaults [interval: 10_000]

  def child_spec(opts) do
    IO.puts(inspect(opts))
    opts = Keyword.merge(@defaults, opts)

    children =
      with {:ok, accounts} <- Keyword.fetch(opts, :accounts),
           {:ok, interval} <- Keyword.fetch(opts, :interval) do
        IO.puts(inspect(accounts))

        accounts
        |> Stream.map(&Account.new!(&1))
        |> Enum.map(fn account ->
          IO.puts(inspect(interval))
          {__MODULE__.ArticleFetcher, [interval: interval, account: account]}
        end)
      end

    # IO.puts(inspect(children))
    Supervisor.Spec.supervisor(
      Supervisor,
      [children, [strategy: :one_for_one, name: __MODULE__]]
    )
  end

  defmodule ArticleFetcher do
    @moduledoc """
    Process that fetches the articles
    """
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @impl true
    def init(interval: interval, account: %Account{} = account) do
      Logger.info("Starting #{__MODULE__} account=#{account.username}")
      authenticated_account = Account.login(account)
      :timer.send_interval(interval, :tick)
      {:ok, authenticated_account}
    end

    @impl true
    def handle_info(:tick, state) do
      GenServer.cast(__MODULE__, {:update})
      {:noreply, state}
    end

    @impl true
    def handle_cast({:update}, account) do
      Logger.debug("Cron job looking up unread articles")

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
    @spec get_unread_article_messages(Map.t()) :: List.t()
    defp get_unread_article_messages(account = %Account{}) do
      Logger.debug("Getting articles url=#{account.api_url} account=#{account.username}")
      {:ok, unread_articles} = TTRSS.Client.get_all_unread_articles(account.api_url, account.sid)

      unread_articles
      |> Enum.map(&ArticleMessage.new(&1, account))
    end
  end
end
