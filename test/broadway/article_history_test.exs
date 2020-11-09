defmodule Broadway.ArticleHistoryTest do
  use ExUnit.Case

  import Mox

  alias Broadway.{ArticleHistory, ArticleMessage}
  alias TTRSS.Account
  alias TTRSS.Client
  alias TTRSS.MockHelper

  require Logger

  @api_url "http://localhost:8081/api"
  @username "test"
  @password "test"

  describe "is_processed/1" do
    setup do
      MockHelper.mock_login()
      MockHelper.mock_get_all_unread_articles()
      verify_on_exit!()
    end

    test "mark and check" do
      account = Account.new(@api_url, @username, @password, "")

      account = Account.login(account)
      {:ok, unread_articles} = Client.get_all_unread_articles(account.api_url, account.sid)

      unread_articles
      |> Stream.map(fn x -> ArticleMessage.new(x, account) end)
      |> Enum.each(fn x -> ArticleHistory.mark_processed(x) end)

      # wait for cast to finish
      pid = Process.whereis(ArticleHistory)
      assert pid != nil
      :"article_history.dets" = :sys.get_state(pid)

      # assert all recorded
      unread_articles
      |> Stream.map(fn x -> ArticleMessage.new(x, account) end)
      |> Enum.each(fn x -> assert true == ArticleHistory.is_processed(x) end)
    end
  end
end
