# Windows Browser Example
#
# This example specifically demonstrates WSL-to-Windows browser automation.
# A visible browser window will open on your Windows desktop!
#
# Usage:
#   mix run examples/windows_browser.exs
#
# Prerequisites:
#   Start the Windows Playwright server first:
#     powershell.exe -File priv/scripts/start_server.ps1
#
# Options:
#   --endpoint, -e   Specify WebSocket endpoint (default: auto-discover)
#   --headless, -h   Run headless instead of visible (default: false)
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

# Parse args - force remote mode for this example
{_requested_mode, opts} = Support.parse_args(System.argv())

case Support.detect_mode(:remote, opts) do
  {:ok, :remote, playwriter_opts} ->
    endpoint = playwriter_opts[:ws_endpoint]
    IO.puts("Connected to server: #{endpoint}")
    IO.puts("")

    IO.puts("Opening browser and navigating to example.com...")
    IO.puts("Watch your Windows desktop!")
    IO.puts("")

    # Force visible browser for this demo
    visible_opts = Keyword.put(playwriter_opts, :headless, false)

    result =
      Playwriter.with_browser(visible_opts, fn ctx ->
        IO.puts("1. Navigating to example.com...")
        :ok = Playwriter.goto(ctx, "https://example.com")

        IO.puts("2. Waiting 2 seconds (watch the browser!)...")
        Process.sleep(2000)

        IO.puts("3. Taking screenshot...")
        {:ok, png} = Playwriter.screenshot(ctx)
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
        IO.puts("Fetched #{String.length(html)} bytes")
        IO.puts("Screenshot saved to windows_screenshot.png")
        IO.puts("")
        IO.puts("The browser window should have been visible on Windows!")

      {:error, reason} ->
        Support.print_runtime_error(reason, :remote)
        System.halt(1)
    end

  {:error, :remote_unavailable, _reason} ->
    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("ERROR: No Windows Playwright server found")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("")
    IO.puts("Start the server on Windows first:")
    IO.puts("")
    IO.puts("    powershell.exe -File priv/scripts/start_server.ps1")
    IO.puts("")
    IO.puts("Or if the server is running on a different endpoint:")
    IO.puts("")
    IO.puts("    mix run examples/windows_browser.exs --endpoint ws://localhost:3337/")
    IO.puts("")
    IO.puts("For local-only automation (no Windows), use:")
    IO.puts("")
    IO.puts("    mix run examples/fetch_html.exs --local")
    IO.puts("")
    System.halt(1)

  {:error, error_type, reason} ->
    Support.print_error(error_type, reason)
    System.halt(1)
end
