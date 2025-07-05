# Direct test of Playwright connection methods
IO.puts("Testing direct Playwright connection methods...\n")

# Method 1: Using BrowserType.connect
IO.puts("Method 1: Using BrowserType.connect")
try do
  ws_endpoint = System.get_env("PLAYWRIGHT_WS_ENDPOINT") || "ws://localhost:3333/"
  IO.puts("Connecting to: #{ws_endpoint}")
  
  {session, browser} = Playwright.BrowserType.connect(ws_endpoint)
  IO.puts("✓ Connected successfully!")
  
  # Create a page - this should open the browser window
  {:ok, page} = Playwright.Browser.new_page(browser)
  IO.puts("✓ Browser window should be open now!")
  
  # Navigate
  Playwright.Page.goto(page, "https://www.example.com")
  IO.puts("✓ Navigated to example.com")
  
  # Get title
  title = Playwright.Page.title(page)
  IO.puts("✓ Page title: #{title}")
  
  Process.sleep(3000)
  
  # Cleanup
  Playwright.Page.close(page)
  Playwright.Session.close(session)
  
rescue
  e ->
    IO.puts("❌ Method 1 failed: #{inspect(e)}")
end

IO.puts("\n" <> String.duplicate("-", 50) <> "\n")

# Method 2: Using Playwright.connect
IO.puts("Method 2: Using Playwright.connect")
try do
  ws_endpoint = System.get_env("PLAYWRIGHT_WS_ENDPOINT") || "ws://localhost:3333/"
  IO.puts("Connecting to: #{ws_endpoint}")
  
  {:ok, browser} = Playwright.connect(:chromium, %{ws_endpoint: ws_endpoint})
  IO.puts("✓ Connected successfully!")
  
  # Create a page
  {:ok, page} = Playwright.Browser.new_page(browser)
  IO.puts("✓ Browser window should be open now!")
  
  # Navigate
  Playwright.Page.goto(page, "https://www.example.com")
  IO.puts("✓ Navigated to example.com")
  
  Process.sleep(3000)
  
  # Cleanup
  Playwright.Page.close(page)
  Playwright.Browser.close(browser)
  
rescue
  e ->
    IO.puts("❌ Method 2 failed: #{inspect(e)}")
end