defmodule DownloadTest do
  use ExUnit.Case

  alias Util.DownloadTranscode

  require Logger

  test "download and transcode" do
    Temp.track()
    download_temp = Temp.path!()
    transcode_temp = Temp.path!()

    DownloadTranscode.download_http_poison(
      "https://file-examples.com/wp-content/uploads/2017/11/file_example_MP3_700KB.mp3",
      download_temp
    )

    DownloadTranscode.transcode_to_opus(download_temp, transcode_temp)
  end

  # TODO: There's a bug with hackney/HTTPoison with unhandled ssl_close message leak
  # Unexpected message: {:ssl_closed, {:sslsocket, {:gen_tcp, #Port<0.10>, :tls_connection, :undefined}, [#PID<0.460.0>, #PID<0.459.0>]}}
  # And then transfer hangs.  Using httpc instead until this is fixed upstream
  test "redirect article" do
    Temp.track()

    1..4
    |> Enum.map(fn _ ->
      temp_path = Temp.path!()

      Task.async(fn ->
        DownloadTranscode.download_http_poison(
          "https://file-examples.com/wp-content/uploads/2017/11/file_example_MP3_700KB.mp3",
          temp_path
        )
      end)
    end)
    |> Enum.map(&Task.await(&1, 300_000))
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
