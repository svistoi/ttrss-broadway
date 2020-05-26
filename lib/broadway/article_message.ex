defmodule ArticleMessage do
  @enforce_keys [:article_id, :api_url, :sid, :output_dir, :article]
  defstruct article_id: nil,    # calculated unique article id
            api_url: nil,       # tt-rss url where this article came from
            sid: nil,           # authentication SID against the api_url
            username: nil,      # username used to login to the API
            output_dir: nil,    # target where this article is going
            download_url: nil,  # post-processed article map
            article: %{}        # raw article from the fee


  def new(article = %{}, api_url, username, output_dir, sid) do
    # Because we could be connecting to multiple endpoints, the unique article
    # ID needs to be in context of api endpoint; ID 1 on tt-rss A, may be a
    # different article on tt-rss B
    # TODO: see tt-rss article guid definition, looks like an alternative
    article_id = "#{Map.get(article, "id", "no_id")}#{api_url}#{username}"
    %ArticleMessage{
      article_id: article_id,
      api_url: api_url,
      sid: sid,
      username: username,
      output_dir: output_dir,
      article: Map.drop(article, ["content", "comments"])
    }
  end
end
