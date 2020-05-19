defmodule Util.DownloadTranscode do
  import FFmpex
  use FFmpex.Options
  require Logger

  def download_http_poison(url, path) do
    Logger.info("Downloading #{url} to #{path} #{inspect(self())}")
    # Download timeout 1 hour
    timeout = 3_600_000

    do_download = fn ->
      {:ok, file} = File.open(path, [:write])

      headers = [
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0"
      ]

      options = [
        async: :once,
        stream_to: self(),
        follow_redirect: true,
        max_redirect: 20,
        recv_timeout: 1_000,
        ssl: [{:versions, [:"tlsv1.3", :"tlsv1.2"]}]
      ]

      {:ok, resp = %HTTPoison.AsyncResponse{id: ref}} = HTTPoison.get(url, headers, options)
      result = receive_data_loop(ref, resp, file)

      :ok = File.close(file)
      result
    end

    case do_download |> Task.async() |> Task.await(timeout) do
      {:redirect, to} ->
        download_http_poison(to, path)

      other ->
        other
    end
  end

  @spec download_httpc(String.t(), Path.t()) :: {atom, String.t()}
  def download_httpc(url, path) do
    Logger.info("Downloading #{url} to #{path}")

    case :httpc.request(:get, {to_char_list(url), []}, [],
           stream: to_char_list(path),
           autoredirect: true,
           relaxed: true
         ) do
      {:ok, :saved_to_file} ->
        {:ok, path}

      {:error, reason} ->
        Logger.info("Error downloading #{url} #{inspect(reason)}")
        {:error, reason}

      _ ->
        {:error, :unknown}
    end
  end

  defp receive_data_loop(ref, resp, file) do
    receive do
      %HTTPoison.AsyncStatus{id: ^ref, code: code} ->
        Logger.info("AsyncStatus received #{code} #{inspect(self())}")
        HTTPoison.stream_next(resp)

        case code do
          200 ->
            receive_data_loop(ref, resp, file)

          404 ->
            {:error, "File not found"}

          _ ->
            {:error, "Received unexpected status code #{code}"}
        end

      %HTTPoison.AsyncRedirect{id: ^ref, to: to} ->
        Logger.info("Handling Redirect #{inspect(self())}")
        {:redirect, to}

      %HTTPoison.AsyncHeaders{id: ^ref, headers: headers} ->
        Logger.info("Headers received #{inspect(headers)} #{inspect(self())}")
        HTTPoison.stream_next(resp)
        receive_data_loop(ref, resp, file)

      %HTTPoison.AsyncChunk{id: ^ref, chunk: chunk} ->
        # Logger.info("Chunk received")
        IO.binwrite(file, chunk)
        HTTPoison.stream_next(resp)
        receive_data_loop(ref, resp, file)

      %HTTPoison.AsyncEnd{id: ^ref} ->
        Logger.info("Finished downloading #{inspect(self())}")
        {:ok, nil}

      %HTTPoison.Error{id: ^ref, reason: reason} ->
        Logger.info("Error #{inspect(reason)}")
        {:error, "Receiving a response chunk timed out"}

      other ->
        Logger.error("Unexpected default case caught #{inspect(other)}")
        HTTPoison.stream_next(resp)
        {:error, "Unexpected HTTPoison receive message"}
    end
  end

  def transcode_to_opus(input_path, out_path) do
    Logger.info("Transcoding from #{input_path} to #{out_path}")
    :ok = File.mkdir_p(Path.dirname(out_path))

    compression_level = %FFmpex.Option{
      argument: 10,
      contexts: [:output, :per_stream],
      name: "-compression_level",
      require_arg: true
    }

    vbr = %FFmpex.Option{
      argument: "on",
      contexts: [:output, :per_stream],
      name: "-vbr",
      require_arg: true
    }

    FFmpex.new_command()
    |> add_global_option(option_y())
    |> add_input_file(input_path)
    |> add_output_file(out_path)
    |> add_stream_specifier(stream_type: :audio)
    |> add_stream_option(option_codec("libopus"))
    |> add_stream_option(option_b("32K"))
    |> add_stream_option(compression_level)
    |> add_stream_option(vbr)
    |> execute()
  end

  def sanitize_string_for_filename(input) do
    input
    # erase
    |> String.replace(~r([!:\\/?+#%\(\)\"|]), "", global: true)
    # replace with _
    |> String.replace(~r(['\s]+), "_", global: true)
  end

  @spec date_to_str(Date.t()) :: String.t()
  def date_to_str(updated) do
    year = Integer.to_string(updated.year)
    month = Integer.to_string(updated.month)
    month = String.pad_leading(month, 2, "0")
    day = Integer.to_string(updated.day)
    day = String.pad_leading(day, 2, "0")
    "#{year}#{month}#{day}"
  end

  @spec title_to_filename(String.t(), Date.t()) :: <<_::48, _::_*8>>
  def title_to_filename(title, updated) do
    title =
      title
      |> sanitize_string_for_filename()
      # 200 chars max
      |> String.slice(0, 200)

    "#{date_to_str(updated)}_#{title}.opus"
  end

  @spec construct_output_file_path(map, String.t()) :: binary
  def construct_output_file_path(article, out_root) do
    article_date =
      case DateTime.from_unix(article["updated"]) do
        {:ok, t} -> t
        _ -> ~D[1970-01-01]
      end

    feed_folder_name = sanitize_string_for_filename(article["feed_title"])
    podcast_file_name = title_to_filename(article["title"], article_date)
    Path.join([out_root, feed_folder_name, podcast_file_name])
  end
end
