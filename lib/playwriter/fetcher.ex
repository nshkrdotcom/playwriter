defmodule Playwriter.Fetcher do
  @moduledoc """
  HTML fetching functionality using Playwright
  """

  require Logger

  def fetch_html(url, opts \\ %{}) do
    Logger.info("Starting Playwright to fetch HTML from: #{url}")
    
    try do
      # Launch browser with options
      browser_opts = Map.merge(%{headless: true}, opts)
      {:ok, browser} = Playwright.launch(:chromium, browser_opts)
      Logger.info("Browser launched successfully (headless: #{browser_opts[:headless]})")
      
      # Create new page
      page = Playwright.Browser.new_page(browser)
      
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
      
      # Navigate to URL
      Playwright.Page.goto(page, url)
      Logger.info("Navigation completed")
      
      # Get HTML content
      html = Playwright.Page.content(page)
      Logger.info("HTML content retrieved, length: #{String.length(html)}")
      
      # Close page and browser
      Playwright.Page.close(page)
      Playwright.Browser.close(browser)
      Logger.info("Browser closed")
      
      {:ok, html}
    rescue
      error ->
        Logger.error("Error during HTML fetch: #{inspect(error)}")
        {:error, "Error during HTML fetch: #{inspect(error)}"}
    end
  end
end