defmodule Util.DownloadTranscodeTest do
  use ExUnit.Case

  alias Util.DownloadTranscode

  describe "download_http_poison" do
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

    test "parallel with follow redirects" do
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
  end

  describe "sanitize_string_for_filename" do
    test "sanitize_string_for_filename" do
      assert DownloadTranscode.sanitize_string_for_filename("CBC News: World Report for 2020/03/17") ==
               "CBC_News_World_Report_for_20200317"
    end
  end

  describe "title_to_filename" do
    test "title_to_filename" do
      assert DownloadTranscode.title_to_filename("CBC News: World Report for 2020/03/17", ~D[2011-10-11]) ==
               "20111011_CBC_News_World_Report_for_20200317.opus"

      assert DownloadTranscode.title_to_filename("CBC News: World Report", ~D[2000-12-31]) ==
               "20001231_CBC_News_World_Report.opus"
    end
  end
end
