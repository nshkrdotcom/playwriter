#!/usr/bin/env elixir

# Test script to understand remote browser context creation
IO.puts("Testing remote browser context creation...")

# Load the dependencies
Mix.install([
  {:playwright, "~> 1.46"}
])

# Test what happens when we try to create context with various options
ws_endpoint = "ws://172.19.176.1:3333/"
IO.puts("Connecting to: #{ws_endpoint}")

try do
  # Connect to remote browser
  {session, browser} = Playwright.BrowserType.connect(ws_endpoint)
  IO.puts("✓ Connected to browser successfully")
  
  # Test 1: Create context with no options
  IO.puts("\nTest 1: Creating context with no options")
  try do
    context1 = Playwright.Browser.new_context(browser)
    IO.puts("✓ Success: #{inspect(context1)}")
    Playwright.BrowserContext.close(context1)
  rescue
    e -> IO.puts("✗ Error: #{inspect(e)}")
  end
  
  # Test 2: Create context with headless option (this should fail)
  IO.puts("\nTest 2: Creating context with headless option")
  try do
    context2 = Playwright.Browser.new_context(browser, %{headless: false})
    IO.puts("✓ Success: #{inspect(context2)}")
    Playwright.BrowserContext.close(context2)
  rescue
    e -> IO.puts("✗ Error: #{inspect(e)}")
  end
  
  # Test 3: Create context with valid options
  IO.puts("\nTest 3: Creating context with valid options")
  try do
    context3 = Playwright.Browser.new_context(browser, %{
      accept_downloads: true,
      bypass_csp: true
    })
    IO.puts("✓ Success: #{inspect(context3)}")
    Playwright.BrowserContext.close(context3)
  rescue
    e -> IO.puts("✗ Error: #{inspect(e)}")
  end
  
  # Test 4: Create context with viewport option
  IO.puts("\nTest 4: Creating context with viewport option")
  try do
    context4 = Playwright.Browser.new_context(browser, %{
      viewport: %{width: 1920, height: 1080}
    })
    IO.puts("✓ Success: #{inspect(context4)}")
    Playwright.BrowserContext.close(context4)
  rescue
    e -> IO.puts("✗ Error: #{inspect(e)}")
  end
  
  # Clean up
  Playwright.Session.close(session)
  
rescue
  e ->
    IO.puts("❌ Connection or test failed: #{inspect(e)}")
end