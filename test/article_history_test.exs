defmodule ArticleHistoryTest do
  use ExUnit.Case
  require Logger
  alias Broadway.ArticleHistory

  test "mark and check" do
    ArticleHistory.mark_processed("id1")
    ArticleHistory.mark_processed("id2")
    ArticleHistory.mark_processed("id3")
    ArticleHistory.mark_processed("id3") # duplicate

    pid = Process.whereis(ArticleHistory)
    assert pid != nil
    :"article_history.dets" = :sys.get_state(pid)

    assert true == ArticleHistory.is_processed("id1")
    assert true == ArticleHistory.is_processed("id2")
    assert true == ArticleHistory.is_processed("id3")
    assert false == ArticleHistory.is_processed("id4")
  end
end
