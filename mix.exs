defmodule TtrssBroadway.MixProject do
  use Mix.Project

  def project do
    [
      app: :ttrss_broadway,
      version: "0.5.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :telemetry, :httpoison],
      mod: {TTRSSDownloader.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:ffmpex, "~> 0.7.3"},
      {:httpoison, "~> 1.8.0"},
      {:jason, "~> 1.2"},
      {:libcluster, "~> 3.2"},
      {:mox, "~> 1.0", only: :test},
      {:telemetry, "~> 0.4.2"},
      {:temp, "~> 0.4.7"},
      {:timex, "~> 3.6"},
      {:uuid, "~> 1.1" },
      {:yaml_elixir, "~> 2.6.0"},
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]
end
