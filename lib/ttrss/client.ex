defmodule TTRSS.Client do
  @moduledoc """
  Implementation of TT-RSS API client
  """
  require Logger
  @behaviour TTRSS.ClientBehavior

  @http_request_headers [{"Content-Type", "application/json"}]

  @impl true
  def login(api_url, user, pass) do
    with {:ok, response} <-
           make_post_request(%{op: "login", user: user, password: pass}, api_url),
         {:ok, sid} <- Map.fetch(response, "session_id") do
      {:ok, sid}
    end
  end

  @impl true
  def get_all_unread_articles(api_url, sid) do
    # feed id: -4 is special All Articles feed
    {:ok, unread_headlines} = get_unread_headlines(-4, api_url, sid)

    unread_headlines
    |> Stream.map(&Map.get(&1, "id", ""))
    |> Enum.join(",")
    |> get_article(api_url, sid)
  end

  @impl true
  def mark_article_read(%{} = article, api_url, sid) do
    mark_article_read([article], api_url, sid)
  end

  @impl true
  def mark_article_read(articles, api_url, sid) when is_list(articles) do
    response =
      articles
      |> Stream.map(&Map.get(&1, "id", ""))
      |> Enum.join(",")
      # field 2 = unread, mode 0 means "false"
      |> update_article(2, 0, api_url, sid)

    case response do
      {:ok, _message} ->
        :ok

      err ->
        err
    end
  end

  @impl true
  def get_unread_feeds(api_url, sid) do
    # cat_id -3, all feeds excluding virtual
    # cat_id -1, special feeds
    %{
      sid: sid,
      op: "getFeeds",
      unread_only: true,
      include_nested: false,
      cat_id: -3
    }
    |> make_post_request(api_url)
  end

  def make_post_request(body, api_url, headers \\ @http_request_headers) do
    with {:ok, body} <- Jason.encode(body),
         {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           HTTPoison.post(api_url, body, headers),
         {:ok, %{"status" => 0, "content" => content}} <- Jason.decode(body) do
      {:ok, content}
    else
      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "API returned #{status_code}"}

      {:ok, %{"status" => 1, "content" => %{"error" => error}}} ->
        {:error, error}

      error ->
        error
    end
  end

  defp get_unread_headlines(feed_id, api_url, sid) do
    %{sid: sid, op: "getHeadlines", feed_id: feed_id, view_mode: "unread"}
    |> make_post_request(api_url)
  end

  defp get_article("", _api_url, _sid), do: []

  defp get_article(article_ids, api_url, sid) do
    %{sid: sid, op: "getArticle", article_id: article_ids}
    |> make_post_request(api_url)
  end

  defp update_article("", _field, _mode, _api_url, _sid), do: []

  defp update_article(article_ids, field, mode, api_url, sid) do
    %{sid: sid, op: "updateArticle", article_ids: article_ids, field: field, mode: mode}
    |> make_post_request(api_url)
  end
end
