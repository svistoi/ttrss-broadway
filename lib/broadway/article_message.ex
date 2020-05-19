defmodule ArticleMessage do
  @enforce_keys [:article_id, :api_url, :sid, :output_dir, :article]
  defstruct article_id: nil,
            api_url: nil,
            sid: nil,
            output_dir: nil,
            download_url: nil,
            article: %{}

  def new(article = %{}, api_url, output_dir, sid) do
    # Because we could be connecting to multiple endpoints, the unique article
    # ID needs to be in context of api endpoint; ID 1 on tt-rss A, may be a
    # different article on tt-rss B
    # TODO: see tt-rss article guid definition, looks like an alternative
    article_id = "#{Map.get(article, "id", "no_id")}#{api_url}"
    %ArticleMessage{
      article_id: article_id,
      api_url: api_url,
      sid: sid,
      output_dir: output_dir,
      article: Map.drop(article, ["content", "comments"])
    }
  end
end
