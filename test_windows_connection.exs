# Test script to verify Windows browser connection
IO.puts("Testing Windows browser connection...")

# Get Windows host IP
{output, 0} = System.cmd("cat", ["/etc/resolv.conf"])
[_, ip] = Regex.run(~r/nameserver\s+(\d+\.\d+\.\d+\.\d+)/, output)
IO.puts("Windows host IP: #{ip}")

ws_endpoint = "ws://#{ip}:3333/"
IO.puts("Trying to connect to: #{ws_endpoint}")

# Test TCP connection first
uri = URI.parse(ws_endpoint)
case :gen_tcp.connect(String.to_charlist(uri.host), uri.port, [:binary, active: false], 2000) do
  {:ok, socket} ->
    IO.puts("✓ TCP connection successful")
    :gen_tcp.close(socket)
    
    # Now try Playwright connection
    IO.puts("Attempting Playwright connection...")
    try do
      {:ok, browser} = Playwright.connect(:chromium, %{ws_endpoint: ws_endpoint})
      IO.puts("✓ Playwright connection successful!")
      
      # Try to create a page
      {:ok, page} = Playwright.Browser.new_page(browser)
      IO.puts("✓ Page created successfully!")
      
      # Navigate to a simple page
      Playwright.Page.goto(page, "https://example.com")
      IO.puts("✓ Navigation successful!")
      
      # Get the title
      title = Playwright.Page.title(page)
      IO.puts("✓ Page title: #{title}")
      
      # Clean up
      Playwright.Page.close(page)
      Playwright.Browser.close(browser)
      IO.puts("\n✅ All tests passed! Windows browser integration is working.")
      
    rescue
      e ->
        IO.puts("❌ Playwright connection failed: #{inspect(e)}")
        IO.puts("\nTroubleshooting:")
        IO.puts("1. Make sure the Playwright server is running on Windows")
        IO.puts("2. Check if the PowerShell window is still open")
        IO.puts("3. Try running: ./setup_windows_browser.sh")
    end
    
  {:error, reason} ->
    IO.puts("❌ TCP connection failed: #{inspect(reason)}")
    IO.puts("\nThe Playwright server is not reachable.")
    IO.puts("Please run: ./setup_windows_browser.sh")
end