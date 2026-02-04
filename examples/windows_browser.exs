# Windows Browser Example
#
# This example specifically demonstrates WSL-to-Windows browser automation.
# A visible browser window will open on your Windows desktop!
#
# Usage:
#   mix run examples/windows_browser.exs
#
# Prerequisites:
#   Install Playwright on Windows first:
#     powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install
#
# For local-only automation, use the other examples with --local flag.

Code.require_file("support.exs", __DIR__)
alias Playwriter.Examples.Support

IO.puts("=" |> String.duplicate(60))
IO.puts("WSL-to-Windows Browser Demo")
IO.puts("=" |> String.duplicate(60))
IO.puts("")
IO.puts("This will open a VISIBLE browser window on Windows!")
IO.puts("")

# Parse args - force windows mode for this example
{_requested_mode, opts} = Support.parse_args(System.argv())

case Support.detect_mode(:windows, opts) do
  {:ok, :windows, playwriter_opts} ->
    IO.puts("Using Windows mode (PowerShell + Node.js)")
    IO.puts("")

    IO.puts("Opening browser and navigating to example.com...")
    IO.puts("Watch your Windows desktop!")
    IO.puts("")

    result =
      Playwriter.with_browser(playwriter_opts, fn ctx ->
        IO.puts("1. Navigating to example.com...")
        :ok = Playwriter.goto(ctx, "https://example.com")

        IO.puts("2. Waiting 2 seconds (watch the browser!)...")
        Process.sleep(2000)

        IO.puts("3. Taking screenshot...")
        {:ok, png} = Playwriter.take_screenshot(ctx)
        File.write!("windows_screenshot.png", png)
        IO.puts("   Saved to windows_screenshot.png")

        IO.puts("4. Getting page content...")
        {:ok, html} = Playwriter.content(ctx)

        IO.puts("5. Closing browser...")
        html
      end)

    case result do
      {:ok, html} ->
        IO.puts("")
        IO.puts("Success!")
        IO.puts("Fetched #{byte_size(html)} bytes")
        IO.puts("Screenshot saved to windows_screenshot.png")
        IO.puts("")
        IO.puts("The browser window should have been visible on Windows!")

      {:error, reason} ->
        Support.print_runtime_error(reason, :windows)
        System.halt(1)
    end

  {:error, :windows_unavailable, reason} ->
    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("ERROR: Windows mode not available")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("")

    case reason do
      :not_wsl ->
        IO.puts("This example requires running from WSL.")
        IO.puts("")
        IO.puts("Use local mode instead:")
        IO.puts("")
        IO.puts("    mix run examples/fetch_html.exs --local")

      :playwright_not_installed_on_windows ->
        IO.puts("Playwright is not installed on Windows.")
        IO.puts("")
        IO.puts("Run the setup script first:")
        IO.puts("")

        IO.puts(
          "    powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install"
        )

        IO.puts("")
        IO.puts("Then run this example again.")
    end

    IO.puts("")
    System.halt(1)

  {:error, error_type, reason} ->
    Support.print_error(error_type, reason)
    System.halt(1)
end
