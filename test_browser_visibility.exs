# Test browser visibility with a longer session
IO.puts("Testing browser visibility with extended session...")

ws_endpoint = "ws://172.19.176.1:3333/"

try do
  {_session, browser} = Playwright.BrowserType.connect(ws_endpoint)
  IO.puts("✓ Connected to browser")
  
  page = Playwright.Browser.new_page(browser)
  IO.puts("✓ Page created - browser window should be visible now!")
  
  IO.puts("Navigating to Google...")
  Playwright.Page.goto(page, "https://www.google.com")
  
  IO.puts("✓ Page loaded. If headed mode is working, you should see a browser window on Windows.")
  IO.puts("Waiting 10 seconds so you can observe the browser...")
  Process.sleep(10_000)
  
  IO.puts("Navigating to example.com...")
  Playwright.Page.goto(page, "https://example.com")
  
  IO.puts("Waiting another 5 seconds...")
  Process.sleep(5_000)
  
  title = Playwright.Page.title(page)
  IO.puts("Page title: #{title}")
  
  IO.puts("Closing browser...")
  Playwright.Page.close(page)
  Playwright.Browser.close(browser)
  
  IO.puts("✓ Test completed")
  
rescue
  e ->
    IO.puts("❌ Error: #{inspect(e)}")
end