defmodule Mix.Tasks.Playwriter.Setup do
  @moduledoc """
  Provisions and smoke-tests the pinned Playwright driver for one transport.

      mix playwriter.setup
      mix playwriter.setup --mode windows --browser chrome
      mix playwriter.setup --mode windows --browser chrome --check

  Windows accepts `chrome` (installed Google Chrome), `msedge` (installed
  Microsoft Edge), or `chromium` (managed Chrome for Testing). Set
  `PLAYWRITER_WINDOWS_CHANNEL` to use the same selection at runtime.
  Without a Windows selection, setup prints the available choices.

  Local setup accepts `--browser chromium|firefox|webkit|all` and
  `--with-deps` to explicitly request system libraries. Both modes require
  Node.js and npm on the host that runs the browser. `--check` checks files
  and prerequisites without provisioning or launching a browser.
  """

  use Mix.Task
  @shortdoc "Prepare and verify a local or Windows browser"

  alias Playwriter.Setup

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} =
      OptionParser.parse(args,
        strict: [mode: :string, browser: :string, with_deps: :boolean, check: :boolean]
      )

    mode = Keyword.get(opts, :mode, "local")
    browser = opts[:browser]
    with_deps = Keyword.get(opts, :with_deps, false)
    check = Keyword.get(opts, :check, false)

    validate!(positional, invalid, mode, browser, with_deps, check)
    Mix.Task.run("app.config")
    setup(mode, browser, with_deps, check)
  end

  defp setup("local", browser, with_deps, check) do
    browser = browser || "chromium"
    report_selection("local", browser)
    confirm(Setup.install(:local, browser, with_deps, check), "local", check)
  end

  defp setup("windows", requested, false, check) do
    case Setup.windows_browser(requested) do
      {:ok, nil} ->
        Mix.shell().info("""
        Choose a Windows browser with --browser:
          chrome     Installed Google Chrome
          msedge     Installed Microsoft Edge
          chromium   Playwright-managed Chrome for Testing (download)
        You can also set PLAYWRITER_WINDOWS_CHANNEL to one of these values.
        """)

      {:ok, browser} ->
        report_selection("windows", Setup.windows_browser_name(browser))
        confirm(Setup.install(:windows, browser, false, check), "windows", check)
        Mix.shell().info("Use PLAYWRITER_WINDOWS_CHANNEL=#{browser} for subsequent Windows runs.")

      {:error, reason} ->
        Mix.raise(reason)
    end
  end

  defp report_selection(mode, browser) do
    Mix.shell().info("Playwriter #{mode} · Playwright #{Setup.driver_version()} · #{browser}")
  end

  defp confirm(:ok, _mode, true) do
    Mix.shell().info("Prerequisite and file checks passed. Browser launch was not tested.")
  end

  defp confirm(:ok, mode, false) do
    Mix.shell().info("Playwriter #{mode} ready. Browser launch, navigation and shutdown passed.")
  end

  defp confirm({:error, reason}, _mode, _check) when is_binary(reason), do: Mix.raise(reason)

  defp confirm({:error, reason}, mode, _check),
    do: Mix.raise("Playwriter #{mode} setup failed: #{inspect(reason)}")

  defp validate!([], [], mode, browser, with_deps, check) do
    unless valid_options?(mode, browser, with_deps, check), do: invalid_options!()
  end

  defp validate!(_, _, _, _, _, _), do: invalid_options!()

  @spec invalid_options!() :: no_return()
  defp invalid_options!, do: Mix.raise("Invalid setup arguments. See mix help playwriter.setup.")

  defp valid_options?("windows", browser, false, _check),
    do: browser in [nil, "chrome", "msedge", "chromium"]

  defp valid_options?("local", browser, true, false),
    do: browser in [nil, "chromium", "firefox", "webkit", "all"]

  defp valid_options?("local", browser, false, _check),
    do: browser in [nil, "chromium", "firefox", "webkit", "all"]

  defp valid_options?(_, _, _, _), do: false
end
