defmodule TTRSS.ClientTest do
  use ExUnit.Case

  @api_url "http://localhost:8081/api"
  @username "test"
  @password "test"

  test "login" do
    assert {:ok, "12345"} == TTRSS.Client.login(@api_url, @username, @password)
  end

  test "login fail" do
    assert {:error, "LOGIN_ERROR"} == TTRSS.Client.login(@api_url, @username, "wrongpass")
  end

  test "get_all_unread_articles" do
    {:ok, sid} = TTRSS.Client.login(@api_url, @username, @password)
    {:ok, unread_articles} = TTRSS.Client.get_all_unread_articles(@api_url, sid)
    assert 63 == length(unread_articles)
  end

  test "get_unread_feeds" do
    {:ok, sid} = TTRSS.Client.login(@api_url, @username, @password)
    {:ok, unread_feeds} = TTRSS.Client.get_unread_feeds(@api_url, sid)
    assert 5 == length(unread_feeds)
  end

  test "mark_article" do
    {:ok, sid} = TTRSS.Client.login(@api_url, @username, @password)
    assert :ok == TTRSS.Client.mark_article_read(%{"id" => 1}, @api_url, sid)
  end
end
