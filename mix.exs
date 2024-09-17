defmodule OpentelemetryAsh.MixProject do
  use Mix.Project

  @description """
  The Opentelemetry integration for Ash Framework
  """

  @version "0.1.0"

  def project do
    [
      app: :opentelemetry_ash,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      description: @description
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "OpentelemetryAsh",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extra_section: "GUIDES",
      extras: [
        "documentation/tutorials/getting-started-with-opentelemetry-ash.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        "How To": ~r'documentation/how_to',
        Topics: ~r'documentation/topics',
        DSLs: ~r'documentation/dsls',
        "About OpentelemetryAsh": [
          "CHANGELOG.md"
        ]
      ],
      groups_for_modules: [
        OpentelemetryAsh: [
          OpentelemetryAsh
        ],
        Internals: ~r/.*/
      ]
    ]
  end

  defp package do
    [
      name: :opentelemetry_ash,
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*
      CHANGELOG* documentation),
      links: %{
        GitHub: "https://github.com/ash-project/opentelemetry_ash"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, ash_version("~> 3.0")},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:opentelemetry_api, "~> 1.0"},
      {:opentelemetry_process_propagator, "~> 0.3"},
      {:ex_doc, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "main" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end
end
