defmodule Playwriter.MixProject do
  use Mix.Project

  @version "0.3.0"
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

  # Run the aliases that invoke `mix test` in the :test env, so `mix check`
  # (and the test.* aliases) work without an explicit MIX_ENV.
  def cli do
    [
      preferred_envs: [
        check: :test,
        "test.integration": :test,
        "test.windows": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core - playwright_ex drives the local (headless) transport. The Node
      # Playwright driver the :local transport shells out to is provided at the
      # environment level (npm `playwright`, or the `playwright` hex package's
      # bundled cli.js) rather than pinned here - matching playwright_ex's own
      # "executable:" convention and avoiding the gun/cowlib toolchain coupling.
      {:playwright_ex, "~> 0.7"},
      {:nimble_options, "~> 1.1"},
      {:jason, "~> 1.4"},

      # Testing
      {:supertester, "~> 0.5", only: :test},
      {:mox, "~> 1.2", only: :test},

      # Development
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
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
      files:
        ~w(lib assets priv/scripts .formatter.exs mix.exs README.md LICENSE CHANGELOG.md AGENTS.md examples guides),
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
        {"README.md", filename: "readme", title: "Overview"},
        "CHANGELOG.md",
        "LICENSE",
        {"guides/getting-started.md", title: "Getting Started"},
        {"guides/architecture.md", title: "Architecture"},
        {"guides/transports.md", title: "Transport Layer"},
        {"guides/wsl-windows.md", title: "WSL-Windows Integration"},
        {"guides/functions.md", title: "Function Reference"},
        {"guides/automation-capabilities.md", title: "Automation Capabilities"},
        {"guides/examples.md", title: "Usage Examples"},
        {"guides/testing.md", title: "Testing Guide"},
        {"guides/troubleshooting.md", title: "Troubleshooting"},
        {"examples/README.md", filename: "running-examples", title: "Running Examples"}
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/,
        Examples: ~r/examples\/.*/
      ],
      groups_for_modules: [
        "Public API": [Playwriter],
        "Browser Session": [Playwriter.Browser.Session],
        "Transport Layer": [
          Playwriter.Transport,
          Playwriter.Transport.Behaviour,
          Playwriter.Transport.Local,
          Playwriter.Transport.WindowsCmd,
          Playwriter.Transport.Remote
        ],
        "Server Discovery": [
          Playwriter.Server.Discovery,
          Playwriter.Server.Health
        ]
      ]
    ]
  end
end
