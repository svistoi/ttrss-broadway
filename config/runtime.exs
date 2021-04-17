import Config

config :ttrss_broadway,
  workers: System.get_env("WORKERS", "1"),
  main?: System.get_env("MAIN", "true")
