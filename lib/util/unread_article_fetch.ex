defmodule Util.UnreadArticleFetch do
  @moduledoc """
  A periodic tasks to get articles from tt-rss and add them to the Broadway
  Pipeline
  """
  use GenServer
  require Logger
  alias TTRSS.Account
  alias Broadway.ArticleMessage
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

  @impl true
  def handle_info(:tick, state) do
    GenServer.cast(__MODULE__, {:update})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update}, accounts) when is_list(accounts) do
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

  @spec authenticate_accounts(List.t) :: List.t
  defp authenticate_accounts(accounts) when is_list(accounts) do
    accounts
    |> Stream.map(&Account.new!(&1))
    |> Enum.map(&Account.login(&1))
  end

  # Fetches article given account and returns them via
  @spec get_unread_article_messages(Map.t) :: List.t
  defp get_unread_article_messages(account = %Account{}) do
    Logger.debug("Getting articles for #{account.api_url} destined for #{account.output_dir}")
    {:ok, unread_articles} = TTRSS.Client.get_all_unread_articles(account.api_url, account.sid)

    unread_articles
    |> Enum.map(&ArticleMessage.new(&1, account))
  end
end
