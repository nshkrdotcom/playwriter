defmodule Mix.Tasks.Playwriter.Setup do
  @moduledoc """
  Installs Playwright for local browser automation.

  ## Usage

      mix playwriter.setup

  This will:
  1. Install Playwright npm dependencies in deps/playwright_ex
  2. Download Chromium browser

  ## Options

      mix playwriter.setup --browser firefox    # Install Firefox instead
      mix playwriter.setup --browser all        # Install all browsers

  ## After Setup

  You can then use Playwriter in local mode:

      Playwriter.fetch_html("https://example.com")

  For WSL-to-Windows (remote mode), no local setup is needed.
  Just start the Windows server and use `mode: :remote`.
  """

  use Mix.Task

  @shortdoc "Install Playwright for local browser automation"
  @playwright_ex_path Path.join(["deps", "playwright_ex"])

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [browser: :string])
    browser = opts[:browser] || "chromium"

    Mix.shell().info("Setting up Playwright for local browser automation...")
    Mix.shell().info("")

    verify_deps_exist!()
    install_npm_deps!()
    install_browser!(browser)
    print_linux_hint(browser)
    print_success_message()
  end

  defp verify_deps_exist! do
    unless File.dir?(@playwright_ex_path) do
      Mix.shell().error("Error: playwright_ex dependency not found.")
      Mix.shell().error("Run `mix deps.get` first.")
      System.halt(1)
    end
  end

  defp install_npm_deps! do
    Mix.shell().info("Step 1: Installing npm dependencies...")

    case System.cmd("npm", ["install"], cd: @playwright_ex_path, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info("npm dependencies installed.")
        Mix.shell().info("")

      {output, code} ->
        Mix.shell().error("npm install failed (exit code #{code}):")
        Mix.shell().error(output)
        Mix.shell().error("")
        Mix.shell().error("Make sure Node.js and npm are installed:")
        Mix.shell().error("  https://nodejs.org/")
        System.halt(1)
    end
  end

  defp install_browser!(browser) do
    browser_arg = if browser == "all", do: [], else: [browser]
    npx_args = ["playwright", "install"] ++ browser_arg

    Mix.shell().info("Step 2: Installing #{browser} browser...")

    case System.cmd("npx", npx_args, cd: @playwright_ex_path, stderr_to_stdout: true) do
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
        Mix.shell().info("If you see browser launch errors, run:")
        Mix.shell().info("  npx playwright install-deps #{browser}")
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
