defmodule Broadway.DownloadPipeline do
  use Broadway
  require Logger

  alias Util.DownloadTranscode
  alias Broadway.Message

  def start_link(_opts) do
    Logger.info("Starting #{__MODULE__}")
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Broadway.UnreadMessageProducer, []}
      ],
      processors: [
        default: [
          concurrency: 2,
          min_demand: 500,
          max_demand: 1000
        ]
      ],
      batchers: [
        default: [],
        audio_download_transcode: [concurrency: 1, batch_size: 10, batch_timeout: 1_000]
      ]
    )
  end

  @impl true
  def handle_message(_, %Message{data: data} = message, _context) do
    case audio_attachment_filter(data.article) do
      {:audio_download_transcode, download_url} ->
        message
        |> Message.update_data(fn data ->
          %ArticleMessage{data | download_url: download_url}
        end)
        |> Message.put_batcher(:audio_download_transcode)
        |> Message.put_batch_key(download_url)

      _ ->
        message
    end
  end

  @impl true
  def handle_batch(:audio_download_transcode, messages, batch_info, context) do
    Logger.info("#{inspect(batch_info)}, #{inspect(context)}")
    {:ok, download_temp_path} = Temp.path()
    {:ok, transcode_temp_path} = Temp.path(%{suffix: ".opus"})

    try do
      {:ok, _} = DownloadTranscode.download_httpc(batch_info.batch_key, download_temp_path)
      :ok = DownloadTranscode.transcode_to_opus(download_temp_path, transcode_temp_path)

      messages
      |> Enum.each(fn message ->
        out_path =
          DownloadTranscode.construct_output_file_path(message.data.article, message.data.output_dir)

        if not File.exists?(out_path) do
          Logger.info("Copying #{transcode_temp_path} to #{out_path}")
          :ok = File.mkdir_p(Path.dirname(out_path))
          :ok = File.cp!(transcode_temp_path, out_path)
        end

        :ok = TTRSS.Client.mark_article_read(message.data.article, message.data.api_url, message.data.sid)
      end)
    catch
      err -> "Error downloading #{inspect(err)}"
    after
      _ = File.rm(download_temp_path)
      _ = File.rm(transcode_temp_path)
    end

    messages
  end

  def handle_batch(:default, messages, _batch_info, _context) do
    messages
  end

  def audio_attachment_filter(article) do
    found =
      Map.get(article, "attachments", [])
      |> Enum.find(false, fn attachment ->
        Map.has_key?(attachment, "content_url") and
          String.starts_with?(Map.get(attachment, "content_type", ""), "audio")
      end)

    if found do
      {:audio_download_transcode, Map.get(found, "content_url")}
    else
      {:error, "No audio attachments"}
    end
  end
end
