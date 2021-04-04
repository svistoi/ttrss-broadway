import Config

config :ttrss_broadway,
  workers: System.get_env("WORKERS", "2"),
  main?: System.get_env("MAIN", "true")
