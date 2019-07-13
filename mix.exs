defmodule Opencensus.Absinthe.MixProject do
  use Mix.Project

  @description "Integration between OpenCensus and Absinthe"

  def project do
    [
      app: :opencensus_absinthe,
      deps: deps(),
      description: @description,
      dialyzer: dialyzer(),
      docs: docs(),
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        credo: :test,
        docs: :docs,
        inch: :docs,
        "inch.report": :docs,
        "inchci.add": :docs,
        licenses: :test,
        "test.watch": :test
      ],
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.2.0"
    ]
  end

  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package() do
    [
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/amplifiedai/opencensus_absinthe",
        "OpenCensus" => "https://opencensus.io",
        "OpenCensus Erlang" => "https://github.com/census-instrumentation/opencensus-erlang",
        "OpenCensus BEAM" => "https://github.com/opencensus-beam"
      }
    ]
  end

  defp deps() do
    [
      {:absinthe, "~> 1.4.0"},
      {:absinthe_plug, "~> 1.4.0", optional: true},
      {:credo, "~> 1.1.0", only: :test},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:docs, :test]},
      {:excoveralls, "~> 0.11.1", only: :test},
      {:inch_ex, "~> 2.0.0", only: :docs},
      {:jason, "~> 1.0", only: [:docs, :test]},
      {:licensir, "~> 0.4.0", only: :test},
      {:mix_test_watch, "~> 0.8", only: :test},
      {:opencensus, "~> 0.9.2"},
      {:opencensus_elixir, "~> 0.4.0"},
      {:opencensus_plug, "~> 0.3", only: :test},
      {:telemetry, "~> 0.4"}
    ]
  end

  defp dialyzer() do
    [
      plt_add_deps: :apps_direct,
      ignore_warnings: "dialyzer.ignore-warnings"
    ]
  end

  defp docs() do
    [
      main: "Opencensus.Absinthe",
      extras: [],
      deps: [
        opencensus: "https://hexdocs.pm/opencensus/"
      ]
    ]
  end
end
