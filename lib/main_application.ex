defmodule MainApplication do
  @moduledoc false
  require Logger
  use Application

  def start(_type, args) do
    config_yaml = load_configuration("config.yaml")
    Logger.debug("Using configuration: #{inspect(config_yaml)}")
    accounts = Map.fetch!(config_yaml, "accounts")

    children = [
      Broadway.DownloadPipeline
    ]

    # During testing startup mock TTRSS server through cowboy/plug
    # During normal execution, startup the periodic article fetch from actual TTRSS
    # server configuration
    additional_children =
      case args do
        [env: :test] ->
          [{Plug.Cowboy, scheme: :http, plug: TTRSS.MockServer, options: [port: 8081]}]

        [_] ->
          [{Util.UnreadArticleFetch, [accounts: accounts]}]
      end

    children = children ++ additional_children
    Logger.info("Starting main application #{__MODULE__}")
    Logger.debug("Supervised children: #{inspect(children)}")
    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defp load_configuration(path) do
    case YamlElixir.read_all_from_file(path) do
      {:ok, [config_yaml]} ->
        config_yaml

      _ ->
        %{"accounts" => []}
    end
  end
end