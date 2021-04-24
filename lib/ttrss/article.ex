defmodule TTRSS.Article do
  @moduledoc """
  Message struct passed around by this Broadway instance
  """
  alias __MODULE__

  @type t :: __MODULE__

  @enforce_keys [:article_id, :account]
  # For hashing purposes (keeping track of messages sent out for processing) composite key
  defstruct article_id: nil,
            # account structure this article came from
            account: nil,
            # raw ttrss article
            article: %{},
            # location where article was downloaded
            saved_path: nil,
            saved_node: nil

  def new(%{} = article, %TTRSS.Account{} = account) do
    # Because we could be connecting to multiple endpoints, the unique article
    # ID needs to be in context of api endpoint; ID 1 on tt-rss A, may be a
    # different article on tt-rss B
    #
    # Lots of options how to calculate the composite key include "id" from tt-rss
    #
    # Article title, shouldn't use id because on article re-publish the id will
    # be different
    title = Map.get(article, "title", "")
    # feed id, not feed_title, I can rename the feed
    feed_id = Map.get(article, "feed_id", "")
    article_id = "#{title}-#{feed_id}-#{account.api_url}-#{account.username}"

    %Article{
      article_id: article_id,
      account: account,
      article: Map.drop(article, ["content", "comments"])
    }
  end

  def set_download_path(%Article{} = article, path, node \\ Node.self()) do
    %Article{article | saved_path: path, saved_node: node}
  end

  def has_audio_attachment?(%Article{} = article) do
    not is_nil(get_audio_attachment_url(article))
  end

  def get_audio_attachment_url(%Article{article: article}) do
    article
    |> Map.get("attachments", [])
    |> Enum.find(%{}, fn attachment ->
      attachment
      |> Map.get("content_type", "")
      |> String.starts_with?("audio")
    end)
    |> Map.get("content_url", nil)
  end

  @spec construct_output_file_path(Article.t()) :: Path.t()
  def construct_output_file_path(%Article{article: article, account: account}) do
    timestamp =
      case DateTime.from_unix(article["updated"]) do
        {:ok, t} -> t
        _ -> ~D[1970-01-01]
      end
      |> Timex.format!("{YYYY}{0M}{0D}")

    title =
      article["title"]
      |> sanitize_string_for_filename()
      |> String.slice(0, 200)

    podcast_file_name = "#{timestamp}_#{title}.opus"

    feed_folder_dir = sanitize_string_for_filename(article["feed_title"])
    Path.join([account.output_dir, feed_folder_dir, podcast_file_name])
  end

  defp sanitize_string_for_filename(input) do
    input
    |> String.replace(~r([!:\\/?+#%\(\)\"|]), "", global: true)
    |> String.replace(~r(['\s]+), "_", global: true)
  end
end
