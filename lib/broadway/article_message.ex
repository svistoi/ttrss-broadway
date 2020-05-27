defmodule Broadway.ArticleMessage do
  alias __MODULE__

  @enforce_keys [:article_id, :account]
  # For hashing purposes (keeping track of messages sent out for processing) article_id is calculated
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
    # TODO: see tt-rss article guid definition, looks like an alternative
    article_id = "#{Map.get(article, "id", "no_id")}#{account.api_url}#{account.username}"

    %ArticleMessage{
      article_id: article_id,
      account: account,
      article: Map.drop(article, ["content", "comments"])
    }
  end
end
