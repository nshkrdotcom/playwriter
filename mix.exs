defmodule Playwriter.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/playwriter"

  def project do
    [
      app: :playwriter,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:mix, :ex_unit]
      ],

      # Hex
      package: package(),
      description: description(),

      # Docs
      name: "Playwriter",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core - using playwright_ex
      {:playwright_ex, "~> 0.3.2"},
      {:nimble_options, "~> 1.1"},
      {:websockex, "~> 0.4.3"},
      {:jason, "~> 1.4"},

      # Testing
      {:supertester, "~> 0.5.1", only: :test},
      {:mox, "~> 1.1", only: :test},

      # Development
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "deps.compile"],
      check: [
        "format --check-formatted",
        "credo --strict",
        "compile --warnings-as-errors",
        "dialyzer",
        "test"
      ],
      "test.integration": ["test --include integration"],
      "test.windows": ["test --include requires_windows_server"]
    ]
  end

  defp package do
    [
      name: "playwriter",
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      maintainers: ["NSHkr"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp description do
    "Elixir browser automation with WSL-to-Windows support. Control visible Windows browsers from WSL."
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      logo: "assets/playwriter.svg",
      assets: %{"assets" => "assets"},
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        {"guides/getting-started.md", title: "Getting Started"},
        {"guides/architecture.md", title: "Architecture"},
        {"guides/transports.md", title: "Transport Layer"},
        {"guides/wsl-windows.md", title: "WSL-Windows Integration"},
        {"guides/functions.md", title: "Function Reference"},
        {"guides/examples.md", title: "Examples"},
        {"guides/troubleshooting.md", title: "Troubleshooting"}
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        "Public API": [Playwriter],
        "Browser Session": [Playwriter.Browser.Session],
        "Transport Layer": [
          Playwriter.Transport.Behaviour,
          Playwriter.Transport.Local,
          Playwriter.Transport.Remote
        ],
        "Server Discovery": [Playwriter.Server.Discovery]
      ]
    ]
  end
end
