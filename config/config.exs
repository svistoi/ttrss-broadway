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

config :libcluster,
  topologies: [
    ttrss: [
      strategy: Cluster.Strategy.Epmd,
      config: [hosts: [:"a@127.0.0.1", :"b@127.0.0.1"]],
    ]
  ]

import_config "#{Mix.env()}.exs"
