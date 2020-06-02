defmodule Broadway.ArticleMessage do
  alias __MODULE__

  @enforce_keys [:article_id, :account]
  # For hashing purposes (keeping track of messages sent out for processing) composite key
  defstruct article_id: nil,
            # account structure this article came from
            account: nil,
            # extracted url for downloading attachment
            download_url: nil,
            # raw ttrss article
            article: %{}

  def new(article = %{}, account = %TTRSS.Account{}) do
    # Because we could be connecting to multiple endpoints, the unique article
    # ID needs to be in context of api endpoint; ID 1 on tt-rss A, may be a
    # different article on tt-rss B
    #
    # Lots of options how to calculate the composite key include "id" from tt-rss
    #
    # Article title, shouldn't use id because on article re-publish the id will
    # be different
    title = Map.get(message.article, "title", "")
    # feed id, not feed_title, I can rename the feed
    feed_id = Map.get(message.article, "feed_id", "")
    article_id = "#{title}-#{feed_id}-#{message.account.api_url}-#{message.account.username}"

    %ArticleMessage{
      article_id: article_id,
      account: account,
      article: Map.drop(article, ["content", "comments"])
    }
  end
end
