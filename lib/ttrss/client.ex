defmodule TTRSS.Client do
  @moduledoc false

  @client Application.compile_env(:ttrss_broadway, :ttrss_client, TTRSS.HTTPClient)

  defdelegate login(api_url, user, pass), to: @client
  defdelegate get_all_unread_articles(api_url, sid), to: @client
  defdelegate mark_article_read(articles, api_url, sid), to: @client
  defdelegate get_unread_feeds(api_url, sid), to: @client
end
