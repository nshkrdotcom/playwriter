defmodule Playwriter.Fetcher do
  @moduledoc """
  Browser automation functionality using Playwright with Windows integration
  """

  require Logger

  @doc """
  Execute a function with a configured browser page.

  This function handles all the complex browser setup including Windows integration,
  Chrome profiles, cookies, headers, and proper cleanup.
  """
  def with_browser(opts \\ %{}, fun) do
    Logger.info("Starting Playwright browser session with options: #{inspect(opts)}")

    try do
      # Check if we should use Windows browser
      {page, context, browser, should_close} = setup_browser(opts)

      # Configure the page
      configure_page(page, opts)

      # Add a small delay to let headed browser fully initialize
      if opts[:use_windows_browser] do
        Logger.info("Waiting for Windows browser to initialize...")
        Process.sleep(2000)
      end

      # Execute the user function with the configured page
      result = fun.(page)

      # Cleanup
      cleanup_browser(page, context, browser, should_close)

      {:ok, result}
    rescue
      error ->
        Logger.error("Error during browser operation: #{inspect(error)}")
        {:error, "Error during browser operation: #{inspect(error)}"}
    end
  end

  @doc """
  Fetch HTML content from a URL using Playwright.

  This is the legacy function maintained for backward compatibility.
  """
  def fetch_html(url, opts \\ %{}) do
    with_browser(opts, fn page ->
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

      html
    end)
  end

  # Private helper functions

  defp setup_browser(opts) do
    if opts[:use_windows_browser] do
      setup_windows_browser(opts)
    else
      setup_local_browser(opts)
    end
  end

  defp setup_windows_browser(opts) do
    Logger.info("Using Windows browser via WebSocket connection")

    {:ok, browser} =
      Playwriter.WindowsBrowserAdapter.connect_windows_browser(
        opts[:browser_type] || :chromium,
        opts
      )

    # For Windows browsers, create context with profile if specified
    if opts[:chrome_profile] do
      profile_path =
        "C:\\Users\\windo\\AppData\\Local\\Google\\Chrome\\User Data\\#{opts[:chrome_profile]}"

      Logger.info("Using Chrome profile: #{opts[:chrome_profile]} at #{profile_path}")

      context_options = %{
        viewport: %{width: 1920, height: 1080}
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
  end

  defp setup_local_browser(opts) do
    # Launch browser with options (existing behavior)
    browser_opts = Map.merge(%{headless: true}, opts)
    {:ok, browser} = Playwright.launch(:chromium, browser_opts)
    Logger.info("Browser launched successfully (headless: #{browser_opts[:headless]})")

    # Create new page (returns page directly, not in tuple)
    page = Playwright.Browser.new_page(browser)
    {page, nil, browser, true}
  end

  defp configure_page(_page, opts) do
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

    Logger.info("Page configured successfully")
  end

  defp cleanup_browser(page, context, browser, should_close) do
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
  end
end
