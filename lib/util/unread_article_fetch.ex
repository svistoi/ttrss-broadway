defmodule Util.UnreadArticleFetch do
  # A periodic tasks to get articles from tt-rss and add them to the Broadway
  # Pipeline
  use GenServer
  require Logger

  @defaults [interval: 10_000]

  def start_link(opts) do
    opts = Keyword.merge(@defaults, opts)
    Logger.info("Starting #{__MODULE__}")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    with {:ok, accounts} <- Keyword.fetch(opts, :accounts),
         {:ok, interval} <- Keyword.fetch(opts, :interval) do
      authenticated_accounts = authenticate_accounts(accounts)
      :timer.send_interval(interval, :tick)
      {:ok, authenticated_accounts}
    end
  end

  def trigger_update() do
    GenServer.cast(__MODULE__, {:update})
  end

  @impl true
  def handle_info(:tick, state) do
    trigger_update()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update}, accounts) do
    Logger.debug("Cron job looking up unread articles")

    unread_articles =
      accounts
      |> Enum.flat_map(&get_unread_article_messages(&1))

    producer_name =
      Broadway.producer_names(Broadway.DownloadPipeline)
      |> Enum.random()

    Logger.debug(
      "Pushing #{length(unread_articles)} articles to Broadway Producer #{inspect(producer_name)}"
    )

    GenStage.cast(producer_name, {:notify, unread_articles})

    {:noreply, accounts}
  end

  defp authenticate_accounts(accounts) do
    accounts
    |> Enum.map(fn account ->
      api_url = Map.fetch!(account, "api")
      username = Map.fetch!(account, "username")
      password = Map.fetch!(account, "password")
      {:ok, sid} = TTRSS.Client.login(api_url, username, password)
      Map.put(account, "sid", sid)
    end)
  end

  # Fetches article given account and returns them via
  defp get_unread_article_messages(account) do
    output_dir = Map.fetch!(account, "output")
    api_url = Map.fetch!(account, "api")
    sid = Map.fetch!(account, "sid")
    Logger.debug("Getting articles for #{api_url} destined for #{output_dir}")

    {:ok, unread_articles} = TTRSS.Client.get_all_unread_articles(api_url, sid)

    unread_articles
    |> Enum.map(&ArticleMessage.new(&1, api_url, output_dir, sid))
  end
end
