defmodule Playwriter.MixProject do
  use Mix.Project

  @version "0.0.2"
  @source_url "https://github.com/nshkrdotcom/playwriter"

  def project do
    [
      app: :playwriter,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: Playwriter.CLI],
      
      # Hex package configuration
      package: package(),
      description: description(),
      
      # Documentation
      name: "Playwriter",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      
      # Build tools
      preferred_cli_env: [
        "hex.publish": :dev
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Cross-platform browser automation for Elixir with advanced WSL-to-Windows integration.
    Features headed browser support, Chrome profile integration, and WebSocket-based 
    remote browser control for seamless automation across platforms.
    """
  end

  defp package do
    [
      name: "playwriter",
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        # Essential scripts for Windows integration
        "start_true_headed_server.sh",
        "kill_playwright.ps1", 
        "list_chrome_profiles.ps1",
        "start_chromium.ps1"
      ],
      maintainers: ["NSHkr"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://hexdocs.pm/playwriter"
      },
      exclude_patterns: [
        # Development and debug files
        "debug_*",
        "test_*", 
        "check_*",
        "simple_*",
        # Deprecated scripts
        "start_headed_server.sh",
        "start_windows_playwright_server.sh",
        "start_headed_server_3334.ps1",
        "custom_headed_server.js",
        "playwright_server_manager.ps1",
        "manual_*.md",
        # Build artifacts
        "_build",
        "deps"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "diagrams.md"
      ],
      groups_for_modules: [
        "Core": [Playwriter, Playwriter.Fetcher],
        "CLI": [Playwriter.CLI], 
        "Windows Integration": [
          Playwriter.WindowsBrowserAdapter,
          Playwriter.WindowsBrowserDirect
        ]
      ],
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
    <script>
      let initialized = false;

      window.addEventListener("exdoc:loaded", () => {
        if (!initialized) {
          mermaid.initialize({
            startOnLoad: false,
            theme: document.body.className.includes("dark") ? "dark" : "default"
          });
          initialized = true;
        }

        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            graphEl.innerHTML = svg;
            bindFunctions?.(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp before_closing_head_tag(:epub), do: ""

  defp before_closing_body_tag(:html), do: ""

  defp before_closing_body_tag(:epub), do: ""

  defp deps do
    [
      # Core dependencies
      {:playwright, "~> 1.49.1-alpha.2"},
      
      # Documentation
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
