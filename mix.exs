defmodule TtrssBroadway.MixProject do
  use Mix.Project

  def project do
    [
      app: :ttrss_broadway,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env)
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :telemetry, :httpoison],
      mod: {MainApplication, [env: Mix.env]},
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.6"},
      {:jason, "~> 1.1"},  # ffmpex uses older version
      {:temp, "~> 0.4"},
      {:ffmpex, "~> 0.7"},
      {:broadway, "~> 0.6"},
      {:yaml_elixir, "~> 2.4"},
      {:telemetry, "~> 0.4"},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:plug_cowboy, "~> 2.0", only: :test}
    ]
  end
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_),     do: ["lib"]
end