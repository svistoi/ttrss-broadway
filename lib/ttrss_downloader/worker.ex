defmodule TTRSSDownloader.Worker do
  use GenServer

  alias TTRSS.Article
  alias Util.DownloadTranscode

  require Logger

  @group "download_worker"

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def download_transcode(%Article{} = article, timeout \\ 3_600_000) do
    workers = :pg2.get_members(@group)

    # TODO: This needs better node picker

    workers
    |> List.wrap()
    |> Enum.shuffle()
    |> List.first()
    |> GenServer.call({:download_transcode, article}, timeout)
  end

  def test() do
    workers = :pg2.get_members(@group)

    workers
    |> Enum.sort_by(fn worker -> Process.info(worker, :messages) end)
  end

  def check(group_name \\ :workers) do
    :pg2.get_members group_name
  end

  @impl true
  def init([]) do
    Temp.track!()
    :ok = :pg2.create(@group)
    :ok = :pg2.join(@group, self())
    {:ok, nil}
  end

  @impl true
  def handle_call({:download_transcode, %Article{} = article}, _from, _state) do
    download_path = Temp.path!()
    opus_path = Temp.path!(%{prefix: UUID.uuid4(), suffix: ".opus"})

    with download_url when not is_nil(download_url) <- Article.get_audio_attachment_url(article),
      {:ok, _} <- DownloadTranscode.download(download_url, download_path),
      {:ok, _} <- DownloadTranscode.transcode_to_opus(download_path, opus_path),
      :ok <- File.rm(download_path) do
      {:reply, Article.set_download_path(article, opus_path), nil}
    end
  end
end
