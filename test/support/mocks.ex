Mox.defmock(TTRSS.MockClient, for: TTRSS.ClientBehavior)
Mox.defmock(MockHTTPoison, for: HTTPoison.Base)

defmodule TTRSS.MockHelper do
  @moduledoc false

  import Mox

  @sid "12345"

  def mock_login() do
    expect(TTRSS.MockClient, :login, fn _api_url, _user, _pass ->
      {:ok, @sid}
    end)
  end

  def mock_get_all_unread_articles() do
    expect(TTRSS.MockClient, :get_all_unread_articles, fn _api_url, _sid ->
      {:ok,
       [
         %{title: "title1", feed_id: "1"},
         %{title: "title2", feed_id: "1"}
       ]}
    end)
  end
end

defmodule HTTPoison.MockHelper do
  @moduledoc false

  import Mox

  alias HTTPoison.Response

  @sid "12345"

  def mock_login() do
    expect(MockHTTPoison, :post, fn _url, body, _headers ->
      %{"op" => "login", "user" => "test", "password" => "test"} = Jason.decode!(body)

      response_body =
        %{"seq" => 0, "status" => 0, "content" => %{"session_id" => @sid, "api_level" => 14}}
        |> Jason.encode!()

      {:ok, %Response{status_code: 200, body: response_body}}
    end)
  end

  def mock_fail_login() do
    expect(MockHTTPoison, :post, fn _url, body, _headers ->
      %{"op" => "login"} = Jason.decode!(body)

      response_body =
        %{"seq" => 0, "status" => 1, "content" => %{"error" => "LOGIN_ERROR"}}
        |> Jason.encode!()

      {:ok, %Response{status_code: 200, body: response_body}}
    end)
  end

  def mock_get_unread_feeds() do
    expect(MockHTTPoison, :post, fn _url, body, _headers ->
      %{"op" => "getFeeds", "sid" => @sid, "unread_only" => true} = Jason.decode!(body)
      {:ok, %Response{status_code: 200, body: File.read!("test/support/unread_feeds.json")}}
    end)
  end

  def mock_get_unread_headlines() do
    expect(MockHTTPoison, :post, fn _url, body, _headers ->
      %{"op" => "getHeadlines", "sid" => "12345", "view_mode" => "unread"} = Jason.decode!(body)
      {:ok, %Response{status_code: 200, body: File.read!("test/support/mixed_unread_headlines.json")}}
    end)
  end

  def mock_get_article() do
    expect(MockHTTPoison, :post, fn _url, body, _headers ->
      %{"op" => "getArticle", "sid" => @sid} = Jason.decode!(body)
      {:ok, %Response{status_code: 200, body: File.read!("test/support/mixed_unread_articles.json")}}
    end)
  end

  def mock_mark_article_read(expected_ids) do
    expect(MockHTTPoison, :post, fn _url, body, _headers ->
      %{"op" => "updateArticle", "sid" => @sid, "article_ids" => ^expected_ids} = Jason.decode!(body)

      response_body =
        %{"seq" => 0, "status" => 0, "content" => %{"success" => "message"}}
        |> Jason.encode!()

      {:ok, %Response{status_code: 200, body: response_body}}
    end)
  end
end
