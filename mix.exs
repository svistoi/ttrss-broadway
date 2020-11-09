defmodule TtrssBroadway.MixProject do
  use Mix.Project

  def project do
    [
      app: :ttrss_broadway,
      version: "0.4.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :telemetry, :httpoison],
      mod: {MainApplication, [env: Mix.env()]}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.7.0"},
      # ffmpex uses older version
      {:jason, "~> 1.2", override: true},
      {:temp, "~> 0.4.7"},
      {:ffmpex, "~> 0.7.3"},
      {:broadway, "~> 0.6.2"},
      {:yaml_elixir, "~> 2.5.0"},
      {:telemetry, "~> 0.4.2"},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]
end
