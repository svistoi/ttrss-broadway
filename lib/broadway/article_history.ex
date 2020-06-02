defmodule Broadway.ArticleHistory do
  @moduledoc """
  DETS implementation of article history. Sometimes RSS feeds reset
  potentially re-download gigabytes of data.

  Mark off the articles downloaded: per account, by their feed title and
  article title
  """

  use GenServer
  require Logger
  alias Broadway.ArticleMessage

  @defaults [database_path: "article_history.dets"]

  def start_link(opts) do
    opts = Keyword.merge(@defaults, opts)
    Logger.info("Starting #{__MODULE__}")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    database_path = Keyword.fetch!(opts, :database_path)
    :dets.open_file(String.to_atom(database_path), type: :set)
  end

  def is_processed(message = %ArticleMessage{}) do
    GenServer.call(__MODULE__, {:is_processed, message})
  end

  def mark_processed(message = %ArticleMessage{}) do
    GenServer.cast(__MODULE__, {:mark_processed, message})
  end

  @impl true
  def handle_call({:is_processed, message = %ArticleMessage{}}, _from, table) do
    article_id = message.article_id
    case :dets.lookup(table, article_id) do
      [{^article_id, true}] ->
        {:reply, true, table}

      _ ->
        {:reply, false, table}
    end
  end

  @impl true
  def handle_cast({:mark_processed, message = %ArticleMessage{}}, table) do
    :ok = :dets.insert(table, {message.article_id, true})
    {:noreply, table}
  end
end
