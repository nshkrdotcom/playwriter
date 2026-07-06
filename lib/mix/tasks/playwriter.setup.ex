defmodule Mix.Tasks.Playwriter.Setup do
  @moduledoc """
  Installs the Node Playwright driver for the `:local` (headless) transport.

  ## Usage

      mix playwriter.setup

  This will, in the project root (using the committed `package.json`, which
  pins the Playwright version `playwright_ex` targets):

  1. Install the Playwright npm package into `node_modules/`
  2. Download the matching Chromium browser

  The `:local` transport then resolves the driver from
  `node_modules/playwright/cli.js` (override with `PLAYWRIGHT_CLI` or
  `config :playwriter, :playwright_cli`).

  ## Options

      mix playwriter.setup --browser firefox    # Install Firefox instead
      mix playwriter.setup --browser all        # Install all browsers
      mix playwriter.setup --with-deps          # Also install OS libs (needs sudo)

  ## After Setup

  You can then use Playwriter in local mode:

      Playwriter.fetch_html("https://example.com")

  For WSL-to-Windows (`mode: :windows`), no local setup is needed - that
  transport provisions its own Node Playwright on the Windows side.
  """

  use Mix.Task

  @shortdoc "Install the Node Playwright driver for :local browser automation"
  @project_root "."

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [browser: :string, with_deps: :boolean])
    browser = opts[:browser] || "chromium"

    Mix.shell().info("Setting up Playwright for local browser automation...")
    Mix.shell().info("")

    verify_manifest_exists!()
    install_npm_deps!()
    install_browser!(browser, opts[:with_deps])
    print_linux_hint(browser)
    print_success_message()
  end

  defp verify_manifest_exists! do
    unless File.exists?(Path.join(@project_root, "package.json")) do
      Mix.shell().error("Error: package.json not found in the project root.")
      Mix.shell().error("This task installs the Node Playwright driver pinned there.")
      System.halt(1)
    end
  end

  defp install_npm_deps! do
    Mix.shell().info("Step 1: Installing the Playwright npm package...")
    # Prefer `npm ci` (reproducible, honours package-lock.json) when a lockfile
    # is present; fall back to `npm install` for a first-time setup.
    npm_args =
      if File.exists?(Path.join(@project_root, "package-lock.json")),
        do: ["ci"],
        else: ["install"]

    case System.cmd("npm", npm_args, cd: @project_root, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info("npm dependencies installed.")
        Mix.shell().info("")

      {output, code} ->
        Mix.shell().error("npm #{hd(npm_args)} failed (exit code #{code}):")
        Mix.shell().error(output)
        Mix.shell().error("")
        Mix.shell().error("Make sure Node.js and npm are installed:")
        Mix.shell().error("  https://nodejs.org/")
        System.halt(1)
    end
  end

  defp install_browser!(browser, with_deps?) do
    browser_arg = if browser == "all", do: [], else: [browser]
    deps_arg = if with_deps?, do: ["--with-deps"], else: []
    npx_args = ["playwright", "install"] ++ deps_arg ++ browser_arg

    Mix.shell().info("Step 2: Installing #{browser} browser...")

    case System.cmd("npx", npx_args, cd: @project_root, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info("Browser installed successfully.")
        Mix.shell().info("")

      {output, code} ->
        Mix.shell().error("Browser installation failed (exit code #{code}):")
        Mix.shell().error(output)
        System.halt(1)
    end
  end

  defp print_linux_hint(browser) do
    case :os.type() do
      {:unix, :linux} ->
        Mix.shell().info("Step 3: Checking system dependencies...")
        Mix.shell().info("If you see browser launch errors about missing libraries, run:")
        Mix.shell().info("  npx playwright install-deps #{browser}   # (needs sudo)")
        Mix.shell().info("  or re-run: mix playwriter.setup --with-deps")
        Mix.shell().info("")

      _ ->
        :ok
    end
  end

  defp print_success_message do
    Mix.shell().info("Setup complete!")
    Mix.shell().info("")
    Mix.shell().info("You can now use Playwriter in local mode:")
    Mix.shell().info("  Playwriter.fetch_html(\"https://example.com\")")
    Mix.shell().info("")
    Mix.shell().info("Or run an example:")
    Mix.shell().info("  mix run examples/fetch_html.exs")
    Mix.shell().info("")
    Mix.shell().info("For WSL-to-Windows (remote mode), no local setup needed.")
    Mix.shell().info("See: mix run examples/fetch_html.exs --remote")
  end
end
