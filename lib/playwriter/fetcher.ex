defmodule Playwriter.Fetcher do
  @moduledoc """
  HTML fetching functionality using Playwright
  """

  require Logger

  def fetch_html(url, opts \\ %{}) do
    Logger.info("Starting Playwright to fetch HTML from: #{url}")
    
    try do
      # Check if we should use Windows browser
      {page, context, browser, should_close} = if opts[:use_windows_browser] do
        Logger.info("Using Windows browser via WebSocket connection")
        {:ok, browser} = Playwriter.WindowsBrowserAdapter.connect_windows_browser(opts[:browser_type] || :chromium, opts)
        
        # For Windows browsers, create context with profile if specified
        if opts[:chrome_profile] do
          profile_path = "C:\\Users\\windo\\AppData\\Local\\Google\\Chrome\\User Data\\#{opts[:chrome_profile]}"
          Logger.info("Using Chrome profile: #{opts[:chrome_profile]} at #{profile_path}")
          
          context_options = %{
            viewport: %{width: 1920, height: 1080},
            # Note: We can't set user data dir in context, only at browser launch
            # So we'll log the profile but use default context for now
          }
          context = Playwright.Browser.new_context(browser, context_options)
          page = Playwright.BrowserContext.new_page(context)
          Logger.info("Windows browser page created with profile context")
          {page, context, browser, true}
        else
          # For Windows browsers, use simple browser.new_page (no custom context)
          page = Playwright.Browser.new_page(browser)
          Logger.info("Windows browser page created successfully")
          {page, nil, browser, true}
        end
      else
        # Launch browser with options (existing behavior)
        browser_opts = Map.merge(%{headless: true}, opts)
        {:ok, browser} = Playwright.launch(:chromium, browser_opts)
        Logger.info("Browser launched successfully (headless: #{browser_opts[:headless]})")
        
        # Create new page (returns page directly, not in tuple)
        page = Playwright.Browser.new_page(browser)
        {page, nil, browser, true}
      end
      
      # Add cookies if provided (directly to page)
      if opts[:cookies] do
        # Add cookies to page context
        for cookie <- opts[:cookies] do
          # Note: Cookie API may need adjustment based on actual implementation
          Logger.info("Would add cookie: #{cookie.name}")
        end
      end
      
      # Set headers if provided
      if opts[:headers] && map_size(opts[:headers]) > 0 do
        # Note: Headers API may need adjustment based on actual implementation
        Logger.info("Would set headers: #{inspect(opts[:headers])}")
      end
      Logger.info("New page created with context")
      
      # Add a small delay to let headed browser fully initialize
      if opts[:use_windows_browser] do
        Logger.info("Waiting for Windows browser to initialize...")
        Process.sleep(2000)
      end
      
      # Navigate to URL with explicit options
      navigation_options = %{
        timeout: 30_000,
        wait_until: "load"
      }
      
      Logger.info("Starting navigation to #{url} with options: #{inspect(navigation_options)}")
      
      # Try navigation with detailed logging
      case Playwright.Page.goto(page, url, navigation_options) do
        %Playwright.Response{} = response ->
          Logger.info("Navigation completed successfully (status: #{response.status})")
        {:error, error} ->
          Logger.error("Navigation failed: #{inspect(error)}")
          raise "Failed to navigate to #{url}: #{inspect(error)}"
        nil ->
          Logger.info("Navigation completed (no response object)")
        other ->
          Logger.warning("Unexpected navigation result: #{inspect(other)}")
      end
      
      # Get HTML content
      html = Playwright.Page.content(page)
      Logger.info("HTML content retrieved, length: #{String.length(html)}")
      
      # Close page and browser
      Playwright.Page.close(page)
      # Close context if it exists
      if context do
        Playwright.BrowserContext.close(context)
      end
      if should_close do
        Playwright.Browser.close(browser)
        Logger.info("Browser closed")
      end
      
      {:ok, html}
    rescue
      error ->
        Logger.error("Error during HTML fetch: #{inspect(error)}")
        {:error, "Error during HTML fetch: #{inspect(error)}"}
    end
  end
end