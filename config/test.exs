use Mix.Config

config :ttrss_broadway,
  ttrss_client: TTRSS.MockClient,
  http_client: MockHTTPoison
