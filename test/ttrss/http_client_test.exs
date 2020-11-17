defmodule TTRSS.HTTPClientTest do
  use ExUnit.Case

  import Mox

  alias HTTPoison.MockHelper
  alias TTRSS.HTTPClient

  @api_url "http://localhost:8081/api"
  @username "test"
  @password "test"

  setup do
    verify_on_exit!()
  end

  describe "login/3" do
    test "login" do
      MockHelper.mock_login()
      assert {:ok, "12345"} == HTTPClient.login(@api_url, @username, @password)
    end

    test "login fail" do
      MockHelper.mock_fail_login()
      assert {:error, "LOGIN_ERROR"} == HTTPClient.login(@api_url, @username, "wrongpass")
    end
  end

  describe "get_all_unread_articles/2" do
    test "get_all_unread_articles" do
      MockHelper.mock_login()
      MockHelper.mock_get_unread_headlines()
      MockHelper.mock_get_article()
      {:ok, sid} = HTTPClient.login(@api_url, @username, @password)
      {:ok, unread_articles} = HTTPClient.get_all_unread_articles(@api_url, sid)
      assert 63 == length(unread_articles)
    end
  end

  describe "get_unread_feeds/2" do
    test "get_unread_feeds" do
      MockHelper.mock_login()
      MockHelper.mock_get_unread_feeds()
      {:ok, sid} = HTTPClient.login(@api_url, @username, @password)
      {:ok, unread_feeds} = HTTPClient.get_unread_feeds(@api_url, sid)
      assert 5 == length(unread_feeds)
    end
  end

  describe "mark_article_read" do
    test "single" do
      MockHelper.mock_login()
      MockHelper.mock_mark_article_read("1")
      {:ok, sid} = HTTPClient.login(@api_url, @username, @password)
      assert :ok == HTTPClient.mark_article_read(%{"id" => 1}, @api_url, sid)
    end

    test "list" do
      MockHelper.mock_login()
      MockHelper.mock_mark_article_read("1,2")
      {:ok, sid} = HTTPClient.login(@api_url, @username, @password)
      assert :ok == HTTPClient.mark_article_read([%{"id" => 1}, %{"id" => 2}], @api_url, sid)
    end
  end
end
