defmodule DownloadTest do
  use ExUnit.Case
  require Logger
  alias Util.DownloadTranscode

  test "download and transcode" do
    {:ok, download_temp} = Temp.path()
    {:ok, transcode_temp} = Temp.path()

    DownloadTranscode.download_http_poison(
      "https://file-examples.com/wp-content/uploads/2017/11/file_example_MP3_700KB.mp3",
      download_temp
    )

    DownloadTranscode.transcode_to_opus(download_temp, transcode_temp)
    File.rm(download_temp)
    File.rm(transcode_temp)
  end

  # TODO: There's a bug with hackney/HTTPoison with unhandled ssl_close message leak
  # Unexpected message: {:ssl_closed, {:sslsocket, {:gen_tcp, #Port<0.10>, :tls_connection, :undefined}, [#PID<0.460.0>, #PID<0.459.0>]}}
  # And then transfer hangs.  Using httpc instead until this is fixed upstream
  @tag :skip
  test "redirect article" do
    {:ok, temp1} = Temp.path()
    {:ok, temp2} = Temp.path()
    {:ok, temp3} = Temp.path()
    {:ok, temp4} = Temp.path()

    Task.async(fn ->
      DownloadTranscode.download_http_poison(
        "https://cbc.mc.tritondigital.com/CBC_WR_P/media/wr/wr-6mGl5gAK-20200513.mp3",
        temp1
      )
    end)
    |> Task.await(300_000)

    Task.async(fn ->
      DownloadTranscode.download_http_poison(
        "https://cbc.mc.tritondigital.com/CBC_WR_P/media/wr/wr-6mGl5gAK-20200513.mp3",
        temp2
      )
    end)
    |> Task.await(300_000)

    Task.async(fn ->
      DownloadTranscode.download_http_poison(
        "https://22163.mc.tritondigital.com:443/CBC_WR_P/media-session/60342a3f-9042-499f-8a1a-5d446bb5af16/wr/wr-AjYYQx5o-20200513.mp3",
        temp3
      )
    end)
    |> Task.await(300_000)

    Task.async(fn ->
      DownloadTranscode.download_http_poison(
        "https://podcast-a.akamaihd.net/wr/wr_20200513.mp3",
        temp4
      )
    end)
    |> Task.await(300_000)

    File.rm(temp1)
    File.rm(temp2)
    File.rm(temp3)
    File.rm(temp4)
  end

  test "sanitize_string_for_filename" do
    sanitized = DownloadTranscode.sanitize_string_for_filename("CBC News: World Report for 2020/03/17")

    assert sanitized == "CBC_News_World_Report_for_20200317"

    sanitized = DownloadTranscode.title_to_filename("CBC News: World Report for 2020/03/17", ~D[2011-10-11])

    assert sanitized == "20111011_CBC_News_World_Report_for_20200317.opus"
  end

  test "title_to_filename" do
    sanitized = DownloadTranscode.title_to_filename("CBC News: World Report", ~D[2000-01-01])
    assert sanitized == "20000101_CBC_News_World_Report.opus"
    sanitized = DownloadTranscode.title_to_filename("CBC News: World Report", ~D[2000-12-31])
    assert sanitized == "20001231_CBC_News_World_Report.opus"
  end
end
