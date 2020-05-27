use Mix.Config

config :ssl, protocol_version: :"tlsv1.2"

config :logger,
  backends: [:console],
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

import_config "#{Mix.env()}.exs"
