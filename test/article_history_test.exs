defmodule ArticleHistoryTest do
  use ExUnit.Case
  require Logger
  alias Broadway.ArticleHistory
  alias Broadway.ArticleMessage
  alias TTRSS.Account

  @api_url "http://localhost:8081/api"
  @username "test"
  @password "test"

  test "mark and check" do
    account1 = Account.new(@api_url, @username, @password, "")
    account2 = Account.new(@api_url, "user2", "", "")

    account1 = Account.login(account1)
    {:ok, unread_articles} = TTRSS.Client.get_all_unread_articles(account1.api_url, account1.sid)

    unread_articles
    |> Stream.map(fn x -> ArticleMessage.new(x, account1) end)
    |> Enum.each(fn x -> ArticleHistory.mark_processed(x) end)

    # wait for cast to finish
    pid = Process.whereis(ArticleHistory)
    assert pid != nil
    :"article_history.dets" = :sys.get_state(pid)

    # assert all recorded
    unread_articles
    |> Stream.map(fn x -> ArticleMessage.new(x, account1) end)
    |> Enum.each(fn x -> assert true == ArticleHistory.is_processed(x) end)

    # assert different account is not processed
    unread_articles
    |> Stream.map(fn x -> ArticleMessage.new(x, account2) end)
    |> Enum.each(fn x -> assert false == ArticleHistory.is_processed(x) end)
  end
end
