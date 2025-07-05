# Test headed browser with explicit options
IO.puts("Testing headed browser with options...")

ws_endpoint = "ws://172.19.176.1:3333/"
IO.puts("Connecting to: #{ws_endpoint}")

try do
  # Connect using BrowserType.connect
  {_session, browser} = Playwright.BrowserType.connect(ws_endpoint)
  IO.puts("✓ Connected to browser server")
  
  # Try to create a context with headed options
  IO.puts("Creating browser context with headed options...")
  
  context_options = %{
    # Try to force headed mode
    headless: false,
    # Make the browser window visible
    devtools: true
  }
  
  context = Playwright.Browser.new_context(browser, context_options)
  IO.puts("✓ Context created with options: #{inspect(context_options)}")
  
  # Create page
  page = Playwright.BrowserContext.new_page(context)
  IO.puts("✓ Page created - browser window should be visible now!")
  
  # Navigate to a website
  IO.puts("Navigating to Google...")
  Playwright.Page.goto(page, "https://www.google.com")
  
  # Wait so you can see it
  IO.puts("Browser should be visible now! Waiting 10 seconds...")
  Process.sleep(10_000)
  
  # Get some info
  title = Playwright.Page.title(page)
  content = Playwright.Page.content(page)
  IO.puts("Page title: #{title}")
  IO.puts("Content length: #{String.length(content)}")
  
  # Keep it open a bit longer
  IO.puts("Waiting another 5 seconds before closing...")
  Process.sleep(5_000)
  
  # Clean up
  Playwright.Page.close(page)
  Playwright.BrowserContext.close(context)
  
  IO.puts("Browser closed.")
  
rescue
  e ->
    IO.puts("❌ Error: #{inspect(e)}")
end