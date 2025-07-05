# Debug WebSocket connection issue
IO.puts("Debugging Playwright WebSocket connection...\n")

# First, let's check if we can reach the server at all
endpoints = [
  "localhost",
  "127.0.0.1",
  "host.docker.internal"
]

# Try to get Windows host IP
windows_host = case System.cmd("cat", ["/etc/resolv.conf"]) do
  {output, 0} ->
    case Regex.run(~r/nameserver\s+(\d+\.\d+\.\d+\.\d+)/, output) do
      [_, ip] -> ip
      _ -> nil
    end
  _ -> nil
end

if windows_host, do: endpoints = endpoints ++ [windows_host]

port = 3333

IO.puts("Testing TCP connectivity to port #{port}...\n")

Enum.each(endpoints, fn host ->
  IO.write("Testing #{host}:#{port}... ")
  
  case :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false], 1000) do
    {:ok, socket} ->
      IO.puts("✓ Connected")
      :gen_tcp.close(socket)
    {:error, reason} ->
      IO.puts("✗ Failed: #{inspect(reason)}")
  end
end)

# Now let's try the Playwright connection with the working endpoint
IO.puts("\nNow testing Playwright connections...")

# Try to find a working endpoint
working_host = Enum.find(endpoints, fn host ->
  case :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false], 1000) do
    {:ok, socket} ->
      :gen_tcp.close(socket)
      true
    _ ->
      false
  end
end)

if working_host do
  IO.puts("\nUsing working endpoint: #{working_host}")
  
  # Test with explicit browser type in the connection
  ws_endpoint = "ws://#{working_host}:#{port}/"
  IO.puts("Attempting connection to: #{ws_endpoint}")
  
  # The issue might be that the Elixir library expects a browser-specific endpoint
  # Let's try different approaches
  
  IO.puts("\nAttempt 1: Direct browser type connect")
  try do
    # This might work better as it's more explicit
    {session, browser} = Playwright.BrowserType.connect(ws_endpoint)
    IO.puts("✓ Connected!")
    Playwright.Session.close(session)
  rescue
    e -> IO.puts("✗ Failed: #{inspect(e)}")
  end
  
  IO.puts("\nAttempt 2: Connect with browser type specified")
  try do
    {:ok, browser} = Playwright.connect(:chromium, %{ws_endpoint: ws_endpoint})
    IO.puts("✓ Connected!")
    Playwright.Browser.close(browser)
  rescue
    e -> IO.puts("✗ Failed: #{inspect(e)}")
  end
else
  IO.puts("\n❌ No working endpoint found. Is the Playwright server running?")
  IO.puts("\nTo start the server:")
  IO.puts("1. Open PowerShell on Windows")
  IO.puts("2. Run: cd $env:TEMP")
  IO.puts("3. Run: npx -y playwright install chromium") 
  IO.puts("4. Run: npx -y playwright run-server --port 3333")
end