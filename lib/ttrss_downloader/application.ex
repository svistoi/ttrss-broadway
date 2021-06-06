defmodule TTRSSDownloader.Application do
  @moduledoc false
  use Application

  alias TTRSS.Account
  alias TTRSSDownloader.{PeriodicMainDownloader, Worker}

  require Logger

  @default_interval 60_000

  def start(_type, _args) do
    children = [
      pg(),
      libcluster(),
      Broadway.ArticleHistory,
      {DynamicSupervisor, strategy: :one_for_one, name: TTRSSDownloader.DynamicSupervisor}
    ] ++ workers() ++ main_downloader()

    Logger.info("Starting main application #{__MODULE__}")
    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defp pg do
    %{
      id: :pg,
      start: {:pg, :start_link, []}
    }
  end

  defp libcluster do
    topologies = Application.get_env(:libcluster, :topologies)
    {Cluster.Supervisor, [topologies, [name: ClusterSupervisor]]}
  end

  defp load_configuration(path) do
    case YamlElixir.read_all_from_file(path) do
      {:ok, [config_yaml]} ->
        config_yaml

      _ ->
        %{"accounts" => []}
    end
  end

  defp main_downloader do
    if Application.fetch_env!(:ttrss_broadway, :main?) == "true" do
      config_yaml = load_configuration("config.yaml")

      accounts =
        config_yaml
        |> Map.fetch!("accounts")
        |> Enum.map(&Account.new!(&1))

      [{PeriodicMainDownloader, [interval: @default_interval, accounts: accounts]}]
    else
      []
    end
  end

  defp workers do
    {num_workers, ""} =
      :ttrss_broadway
      |> Application.fetch_env!(:workers)
      |> Integer.parse()

    0..num_workers
    |> Enum.map(fn index -> %{id: "#{Worker}_#{index}", start: {Worker, :start_link, []}} end)
    |> Enum.take(num_workers)
  end
end
