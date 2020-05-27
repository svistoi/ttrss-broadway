defmodule TTRSS.MockServer do
  use Plug.Router

  @sid "12345"

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  post "/api" do
    case conn.params do
      %{"op" => "login", "password" => "test", "user" => "test"} ->
        success_login(conn)

      %{"op" => "login", "password" => _wrongpass, "user" => "test"} ->
        failure_api(conn, "LOGIN_ERROR")

      %{"op" => "getFeeds", "sid" => @sid, "unread_only" => true} ->
        success_unread_feeds(conn)

      %{"op" => "getHeadlines", "sid" => @sid, "feed_id" => -4, "view_mode" => "unread"} ->
        success_unread_headlines(conn)

      %{"op" => "getArticle", "sid" => @sid} ->
        success_unread_articles(conn)

      %{"op" => "updateArticle", "sid" => @sid} ->
        success_generic(conn)

      _ ->
        IO.puts("Unhandled: #{conn.params}")
        Plug.Conn.send_resp(conn, 404, "")
    end
  end

  defp success_login(conn) do
    body = %{"seq" => 0, "status" => 0, "content" => %{"session_id" => @sid, "api_level" => 14}}
    Plug.Conn.send_resp(conn, 200, Jason.encode!(body))
  end

  defp success_generic(conn) do
    body = %{"seq" => 0, "status" => 0, "content" => %{"success" => "message"}}
    Plug.Conn.send_resp(conn, 200, Jason.encode!(body))
  end

  defp success_unread_feeds(conn) do
    Plug.Conn.send_resp(conn, 200, File.read!("test/support/unread_feeds.json"))
  end

  defp success_unread_headlines(conn) do
    Plug.Conn.send_resp(conn, 200, File.read!("test/support/mixed_unread_headlines.json"))
  end

  defp success_unread_articles(conn) do
    Plug.Conn.send_resp(conn, 200, File.read!("test/support/mixed_unread_articles.json"))
  end

  defp failure_api(conn, message) do
    body = %{"seq" => 0, "status" => 1, "content" => %{"error" => message}}
    Plug.Conn.send_resp(conn, 200, Jason.encode!(body))
  end

  plug(:match)
  plug(:dispatch)
end
