# Windows Browser Example
#
# Run: mix run examples/windows_browser.exs
#
# Prerequisites:
# 1. Start the Windows Playwright server:
#    powershell.exe -File priv/scripts/start_server.ps1
#
# 2. Run this from WSL:
#    mix run examples/windows_browser.exs
#
# You should see a browser window open on Windows!

IO.puts("Connecting to Windows Playwright server...")
IO.puts("Make sure the server is running: powershell.exe -File priv/scripts/start_server.ps1")
IO.puts("")

# Try to discover the server
case Playwriter.Server.Discovery.discover() do
  {:ok, endpoint} ->
    IO.puts("Found server at: #{endpoint}")

    case Playwriter.fetch_html("https://example.com", mode: :remote, ws_endpoint: endpoint) do
      {:ok, html} ->
        IO.puts("")
        IO.puts("Success! Fetched #{String.length(html)} bytes")
        IO.puts("The browser window should have been visible on Windows!")

      {:error, reason} ->
        IO.puts("Error fetching: #{inspect(reason)}")
        System.halt(1)
    end

  {:error, :not_found} ->
    IO.puts("Error: No Playwright server found!")
    IO.puts("")
    IO.puts("Please start the server on Windows:")
    IO.puts("  powershell.exe -File priv/scripts/start_server.ps1")
    System.halt(1)
end
