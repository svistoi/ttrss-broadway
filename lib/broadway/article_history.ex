defmodule Broadway.ArticleHistory do
  use GenServer
  require Logger

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

  def is_processed(article_id) do
    GenServer.call(__MODULE__, {:is_processed, article_id})
  end

  def mark_processed(article_id) do
    GenServer.cast(__MODULE__, {:mark_processed, article_id})
  end

  def mark_processed_sync(article_id) do
    GenServer.call(__MODULE__, {:mark_processed, article_id})
  end

  @impl true
  def handle_call({:is_processed, article_id}, _from, table) do
    case :dets.lookup(table, article_id) do
      [{^article_id, true}] ->
        {:reply, true, table}

      _ ->
        {:reply, false, table}
    end
  end

  @impl true
  def handle_cast({:mark_processed, article_id}, table) do
    :ok = :dets.insert(table, {article_id, true})
    {:noreply, table}
  end
end
