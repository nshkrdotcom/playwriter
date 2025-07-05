# Test BrowserType.connect and page creation
IO.puts("Testing BrowserType.connect and page creation...")

ws_endpoint = System.get_env("PLAYWRIGHT_WS_ENDPOINT") || "ws://172.19.176.1:3333/"
IO.puts("Connecting to: #{ws_endpoint}")

try do
  # This method worked for connection
  {session, browser} = Playwright.BrowserType.connect(ws_endpoint)
  IO.puts("✓ Connected successfully!")
  IO.puts("Session: #{inspect(session)}")
  IO.puts("Browser: #{inspect(browser)}")
  IO.puts("Browser type: #{inspect(browser.__struct__)}")
  
  # Let's inspect what functions are available on this browser
  browser_functions = browser.__struct__.__info__(:functions)
  IO.puts("Available functions on browser: #{inspect(browser_functions)}")
  
  # Let's try different ways to create a page
  IO.puts("\nTrying different page creation methods...")
  
  # Method 1: Direct new_page (this failed before)
  IO.puts("Method 1: Browser.new_page(browser)")
  try do
    page = Playwright.Browser.new_page(browser)
    IO.puts("✓ Success: #{inspect(page)}")
  rescue
    e -> IO.puts("✗ Failed: #{inspect(e)}")
  end
  
  # Method 2: Create context first, then page
  IO.puts("\nMethod 2: Browser.new_context -> BrowserContext.new_page")
  try do
    context = Playwright.Browser.new_context(browser)
    IO.puts("✓ Context created: #{inspect(context)}")
    page = Playwright.BrowserContext.new_page(context)
    IO.puts("✓ Page created: #{inspect(page)}")
    
    # Test navigation
    IO.puts("Testing navigation...")
    Playwright.Page.goto(page, "https://example.com")
    IO.puts("✓ Navigation successful!")
    
    # Get title
    title = Playwright.Page.title(page)
    IO.puts("✓ Page title: #{title}")
    
    # Clean up
    Playwright.Page.close(page)
    Playwright.BrowserContext.close(context)
    Playwright.Session.close(session)
    
  rescue
    e -> IO.puts("✗ Failed: #{inspect(e)}")
  end
  
rescue
  e ->
    IO.puts("❌ Connection failed: #{inspect(e)}")
end