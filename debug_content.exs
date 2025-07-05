# Debug what content we're actually getting
IO.puts("Debugging content retrieval...")

ws_endpoint = "ws://172.19.176.1:3333/"

try do
  {_session, browser} = Playwright.BrowserType.connect(ws_endpoint)
  IO.puts("✓ Connected to browser")
  
  page = Playwright.Browser.new_page(browser)
  IO.puts("✓ Page created")
  
  IO.puts("Navigating to httpbin.org/html...")
  Playwright.Page.goto(page, "https://httpbin.org/html")
  
  # Wait a bit for page to load
  Process.sleep(2000)
  
  # Get content immediately
  content = Playwright.Page.content(page)
  IO.puts("Content length: #{String.length(content)}")
  IO.puts("Content preview (first 200 chars):")
  IO.puts(String.slice(content, 0, 200))
  IO.puts("---")
  
  # Try to get title
  title = Playwright.Page.title(page)
  IO.puts("Title: '#{title}'")
  
  # Try to wait for network idle and get content again
  IO.puts("Waiting for network idle...")
  Process.sleep(3000)
  
  content2 = Playwright.Page.content(page)
  IO.puts("Content length after wait: #{String.length(content2)}")
  IO.puts("Content preview after wait (first 200 chars):")
  IO.puts(String.slice(content2, 0, 200))
  
  # Check if page is actually loaded
  url = Playwright.Page.url(page)
  IO.puts("Current URL: #{url}")
  
  Playwright.Page.close(page)
  Playwright.Browser.close(browser)
  
rescue
  e ->
    IO.puts("❌ Error: #{inspect(e)}")
end