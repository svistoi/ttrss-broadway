defmodule Broadway.DownloadPipeline do
  use Broadway
  require Logger

  alias Util.DownloadTranscode
  alias Broadway.Message
  alias Broadway.ArticleMessage

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
        audio_download_transcode: [concurrency: 1, batch_size: 10, batch_timeout: 1_000],
        mark_read: [concurrency: 2, batch_size: 1_000, batch_timeout: 1_000]
      ]
    )
  end

  @impl true
  def handle_message(_, %Message{data: data} = message, _context) do
    case classify_article(message.data) do
      {:audio_download_transcode, new_data} ->
        message
        |> Message.update_data(fn _ -> new_data end)
        |> Message.put_batcher(:audio_download_transcode)
        |> Message.put_batch_key(new_data.download_url)

      {:mark_read, _} ->
        message
        |> Message.put_batcher(:mark_read)
        |> Message.put_batch_key(api_url: data.account.api_url, sid: data.account.sid)

      _ ->
        message
    end
  end

  @impl true
  def handle_batch(:audio_download_transcode, messages, batch_info, _context) do
    Logger.info("Handling batch of audio download/transcode #{inspect(batch_info)}")
    {:ok, download_temp_path} = Temp.path()
    {:ok, transcode_temp_path} = Temp.path(%{suffix: ".opus"})

    try do
      {:ok, _} = DownloadTranscode.download_httpc(batch_info.batch_key, download_temp_path)
      :ok = DownloadTranscode.transcode_to_opus(download_temp_path, transcode_temp_path)

      messages
      |> Enum.each(fn message ->
        out_path =
          DownloadTranscode.construct_output_file_path(
            message.data.article,
            message.data.account.output_dir
          )

        if not File.exists?(out_path) do
          Logger.info("Copying #{transcode_temp_path} to #{out_path}")
          :ok = File.mkdir_p(Path.dirname(out_path))
          :ok = File.cp!(transcode_temp_path, out_path)
        end

        Broadway.ArticleHistory.mark_processed(message.data)

        :ok =
          TTRSS.Client.mark_article_read(
            message.data.article,
            message.data.account.api_url,
            message.data.account.sid
          )
      end)
    catch
      err -> "Error downloading #{inspect(err)}"
    after
      _ = File.rm(download_temp_path)
      _ = File.rm(transcode_temp_path)
    end

    messages
  end

  def handle_batch(:mark_read, messages, batch_info, _context) do
    Logger.info("Handling batch of marking already downloaded articles #{inspect(batch_info)}")
    api_url = Keyword.fetch!(batch_info.batch_key, :api_url)
    sid = Keyword.fetch!(batch_info.batch_key, :sid)

    messages
    |> Enum.map(fn message -> message.data.article end)
    |> TTRSS.Client.mark_article_read(api_url, sid)

    messages
  end

  def handle_batch(:default, messages, _batch_info, _context) do
    messages
  end

  defp classify_article(article = %ArticleMessage{}) do
    [&classify_already_downloaded/1, &classify_for_audio_download/1]
    |> Enum.find_value({:default, nil}, fn lambda ->
      case lambda.(article) do
        {:error, _} ->
          false

        {classification, rest} ->
          Logger.debug("classified #{inspect(article)} as #{inspect(classification)}")
          {classification, rest}
      end
    end)
  end

  defp classify_already_downloaded(message = %ArticleMessage{}) do
    case Broadway.ArticleHistory.is_processed(message) do
      true -> {:mark_read, true}
      false -> {:error, "Haven't seen this article before"}
    end
  end

  defp classify_for_audio_download(message = %ArticleMessage{}) do
    article = message.article

    found =
      Map.get(article, "attachments", [])
      |> Enum.find(false, fn attachment ->
        Map.has_key?(attachment, "content_url") and
          String.starts_with?(Map.get(attachment, "content_type", ""), "audio")
      end)

    if found do
      message = %ArticleMessage{message | download_url: Map.get(found, "content_url")}
      {:audio_download_transcode, message}
    else
      {:error, "No audio attachments"}
    end
  end
end
