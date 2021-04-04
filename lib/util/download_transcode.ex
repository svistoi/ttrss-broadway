defmodule Util.DownloadTranscode do
  @moduledoc """
  Utilities for downloading and transcoding using ffmpeg
  """
  use FFmpex.Options

  import FFmpex

  alias __MODULE__

  require Logger

  @spec download(url :: String.t(), out_path :: Path.t()) :: {:ok, Path.t()}
  def download(url, out_path) do
    Logger.info("Downloading #{url} to #{out_path} #{inspect(self())}")
    # Download timeout 1 hour
    timeout = 3_600_000

    do_download = fn ->
      {:ok, file} = File.open(out_path, [:write])

      headers = [
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0"
      ]

      options = [
        async: :once,
        stream_to: self(),
        follow_redirect: true,
        max_redirect: 20,
        recv_timeout: 1_000
      ]

      {:ok, resp = %HTTPoison.AsyncResponse{id: ref}} = HTTPoison.get(url, headers, options)
      result = receive_data_loop(ref, resp, file)

      :ok = File.close(file)
      result
    end

    case do_download |> Task.async() |> Task.await(timeout) do
      {:redirect, to} -> download(to, out_path)
      other -> other
    end
  end

  @spec download_httpc(String.t(), Path.t()) :: {atom, String.t()}
  def download_httpc(url, path) do
    Logger.info("Downloading #{url} to #{path}")

    case :httpc.request(:get, {to_charlist(url), []}, [],
           stream: to_charlist(path),
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
    |> case do
      :ok -> {:ok, out_path}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec checksum!(Path.t(), atom) :: String.t()
  def checksum!(file_path, checksum_algo \\ :md5) do
    file_path
    |> File.stream!([], 2048)
    |> Enum.reduce(:crypto.hash_init(checksum_algo), fn(chunk, acc) -> :crypto.hash_update(acc, chunk) end)
    |> :crypto.hash_final()
    |> Base.encode16()
  end

  #Util.get_remote_file(:"test@pinebook", "/home/svistoi/phone/my_reading/ansible.pdf", "/tmp/ansible.pdf")
  @spec send_file(Path.t(), pid, non_neg_integer) :: {:ok, checksum :: String.t()}
  def send_file(file_path, pid, chunk_size \\ 8194, checksum_algo \\ :md5) do
    checksum =
      file_path
      |> File.stream!([], chunk_size)
      |> Enum.reduce(:crypto.hash_init(checksum_algo), fn chunk, acc ->
        {:chunk, chunk} = send pid, {:chunk, chunk}
        :crypto.hash_update(acc, chunk)
      end)
      |> :crypto.hash_final()
      |> Base.encode16()

    {:eof, _} = send pid, {:eof, checksum}

    {:ok, checksum}
  end

  @spec get_remote_file(String.t(), Path.t(), Path.t()) :: {:ok, Path.t()} | {:error, :timeout | term}
  def get_remote_file(remote_node, remote_path, local_path) do
    receiver_pid = self()
    send_task = Task.async(fn -> :rpc.call(remote_node, Util.DownloadTranscode, :send_file, [remote_path, receiver_pid]) end)
    {:ok, expected_checksum} = Task.await(send_task)

    {:ok, calculated_checksum} = receive_file(local_path)
    if expected_checksum != calculated_checksum do
      {:error, :transmission_error}
    else
      {:ok, local_path}
    end
  end

  @spec receive_file(Path.t(), atom) :: {:ok, checksum :: String.t()} | {:error, :timeout | term}
  defp receive_file(file_path, checksum_algo \\ :md5) do
    {:ok, file} = File.open(file_path, [:write])
    try do
      Stream.repeatedly(&receive_generator/0)
      |> Enum.reduce_while(:crypto.hash_init(checksum_algo), fn message, acc ->
        case message do
          {:chunk, chunk} ->
            :ok = IO.binwrite(file, chunk)
            {:cont, :crypto.hash_update(acc, chunk)}

          {:eof, _expected_checksum} ->
            calculated_checksum = acc |> :crypto.hash_final() |> Base.encode16()
            {:halt, {:ok, calculated_checksum}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
    after
      File.close(file)
    end
  end

  defp receive_generator do
    receive do
      {:chunk, chunk} -> {:chunk, chunk}
      {:eof, checksum} -> {:eof, checksum}
    after
      10_000 -> {:error, :timeout}
    end
  end
end
