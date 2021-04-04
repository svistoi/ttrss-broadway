use Mix.Config

config :ttrss_broadway,
  http_client: HTTPoison,
  ttrss_client: TTRSS.HTTPClient

config :logger,
  backends: [:console],
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

import_config "#{Mix.env()}.exs"
