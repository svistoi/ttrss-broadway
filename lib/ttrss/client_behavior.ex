defmodule TTRSS.ClientBehavior do
  @moduledoc false
  @callback login(String.t, String.t, String.t) :: {:ok, String.t} | {:error, String.t}
  @callback get_all_unread_articles(String.t, String.t) :: {:ok, List.t}
  @callback mark_article_read(Map.t, String.t, String.t) :: :ok | {:error, String.t}
  @callback get_unread_feeds(String.t, String.t) :: {:ok, List.t}
end
