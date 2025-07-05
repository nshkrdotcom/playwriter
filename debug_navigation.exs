# Debug navigation issues
IO.puts("Debugging navigation...")

ws_endpoint = "ws://172.19.176.1:3333/"

try do
  {_session, browser} = Playwright.BrowserType.connect(ws_endpoint)
  IO.puts("✓ Connected to browser")
  
  page = Playwright.Browser.new_page(browser)
  IO.puts("✓ Page created")
  
  IO.puts("Current URL before navigation: #{Playwright.Page.url(page)}")
  
  IO.puts("Attempting navigation to httpbin.org/html...")
  
  # Check what goto returns
  result = Playwright.Page.goto(page, "https://httpbin.org/html")
  IO.puts("Navigation result: #{inspect(result)}")
  
  IO.puts("Current URL after navigation: #{Playwright.Page.url(page)}")
  
  # Try with wait options
  IO.puts("Trying navigation with wait options...")
  result2 = Playwright.Page.goto(page, "https://httpbin.org/html", %{wait_until: "load"})
  IO.puts("Navigation with wait result: #{inspect(result2)}")
  
  Process.sleep(2000)
  IO.puts("Current URL after wait: #{Playwright.Page.url(page)}")
  
  content = Playwright.Page.content(page)
  IO.puts("Content length: #{String.length(content)}")
  
  Playwright.Page.close(page)
  Playwright.Browser.close(browser)
  
rescue
  e ->
    IO.puts("❌ Error: #{inspect(e)}")
    IO.puts("Error details: #{Exception.format(:error, e, __STACKTRACE__)}")
end