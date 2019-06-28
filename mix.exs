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
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:absinthe_plug, "~> 1.4.0", optional: true},
      {:dataloader, "~> 1.0.0", optional: true},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :docs},
      {:excoveralls, "~> 0.10.6", only: :test},
      {:inch_ex, "~> 2.0.0", only: :docs},
      {:licensir, "~> 0.4.0", only: :test},
      {:mix_test_watch, "~> 0.8", only: :test},
      {:opencensus, "~> 0.9.2"}
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
