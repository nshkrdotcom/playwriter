defmodule Playwriter do
  @version "0.0.1"

  @moduledoc """
  Cross-platform browser automation for Elixir with advanced WSL-to-Windows integration.

  Playwriter provides HTML fetching and web automation capabilities using Playwright,
  with special support for controlling Windows browsers from WSL environments.

  ## Features

  - **Local Browser Automation**: Standard Playwright automation in headless/headed modes
  - **Cross-Platform Integration**: WSL-to-Windows browser control via WebSocket
  - **Windows Browser Support**: Use Windows Chrome/Chromium with existing profiles
  - **Headed Browser Support**: Visible browser windows for debugging and development
  - **Chrome Profile Integration**: Support for existing Chrome user profiles and data

  ## Basic Usage

      # Simple HTML fetching
      {:ok, html} = Playwriter.fetch_html("https://example.com")

      # With custom options
      opts = %{headless: false, use_windows_browser: true}
      {:ok, html} = Playwriter.Fetcher.fetch_html("https://google.com", opts)

  ## CLI Usage

      # Local browser automation
      ./playwriter https://example.com

      # Windows browser integration
      ./playwriter --windows-browser https://google.com

      # List Chrome profiles
      ./playwriter --list-profiles

  ## Windows Integration

  For WSL-to-Windows browser automation:

  1. Start the headed browser server:
     ```bash
     ./start_true_headed_server.sh
     ```

  2. Use Windows browsers from Elixir:
     ```bash
     ./playwriter --windows-browser https://example.com
     ```

  See the [README](https://github.com/nshkrdotcom/playwriter#readme) for detailed setup instructions.

  ## Author

  Created by [NSHkr](https://github.com/nshkrdotcom)

  ## Links

  - **Repository**: https://github.com/nshkrdotcom/playwriter
  - **Hex Package**: https://hex.pm/packages/playwriter
  - **Documentation**: https://hexdocs.pm/playwriter
  """

  @doc """
  Execute a function with a configured browser page.

  This is the main entry point for browser operations. It handles all the complex
  browser setup (including Windows integration) and provides a configured page
  to your function.

  ## Parameters

  - `opts` - Browser configuration options (see below)
  - `fun` - Function that receives a configured page and returns a result

  ## Options

  - `:use_windows_browser` - Use Windows browser via WebSocket (default: false)
  - `:browser_type` - Browser type (:chromium, :firefox, :webkit)
  - `:headless` - Run in headless mode (default: true)
  - `:chrome_profile` - Chrome profile name for Windows browsers
  - `:cookies` - List of cookies to set
  - `:headers` - Headers to set
  - `:ws_endpoint` - Explicit WebSocket endpoint for remote browsers

  ## Returns

  - `{:ok, result}` - Success with result from your function
  - `{:error, reason}` - Error with reason

  ## Examples

      # Basic HTML fetching
      {:ok, html} = Playwriter.with_browser(%{}, fn page ->
        Playwright.Page.goto(page, "https://example.com")
        Playwright.Page.content(page)
      end)

      # Take a screenshot
      {:ok, _} = Playwriter.with_browser(%{}, fn page ->
        Playwright.Page.goto(page, "https://example.com")
        Playwright.Page.screenshot(page, %{path: "screenshot.png"})
      end)

      # Windows browser with profile
      {:ok, html} = Playwriter.with_browser(%{
        use_windows_browser: true,
        chrome_profile: "Profile 1"
      }, fn page ->
        Playwright.Page.goto(page, "https://example.com")
        Playwright.Page.content(page)
      end)

  """
  def with_browser(opts \\ %{}, fun) do
    Playwriter.Fetcher.with_browser(opts, fun)
  end

  @doc """
  Fetch HTML content from a URL using Playwright.

  This is a convenience function that uses `with_browser/2` internally.

  ## Parameters

  - `url` - The URL to fetch HTML from
  - `opts` - Browser configuration options (see `with_browser/2`)

  ## Returns

  - `{:ok, html}` - Success with HTML content as binary
  - `{:error, reason}` - Error with reason

  ## Examples

      # Basic usage
      {:ok, html} = Playwriter.fetch_html("https://example.com")

      # With Windows browser
      {:ok, html} = Playwriter.fetch_html("https://example.com", %{
        use_windows_browser: true,
        chrome_profile: "Default"
      })

  """
  def fetch_html(url, opts \\ %{}) do
    with_browser(opts, fn page ->
      Playwright.Page.goto(page, url)
      Playwright.Page.content(page)
    end)
  end

  @doc """
  Take a screenshot of a URL using Playwright.

  This is a convenience function that uses `with_browser/2` internally.

  ## Parameters

  - `url` - The URL to take a screenshot of
  - `path` - File path to save the screenshot
  - `opts` - Browser configuration options (see `with_browser/2`)

  ## Returns

  - `{:ok, binary}` - Success with screenshot data
  - `{:error, reason}` - Error with reason

  ## Examples

      # Basic usage
      {:ok, _} = Playwriter.screenshot("https://example.com", "screenshot.png")

      # With Windows browser
      {:ok, _} = Playwriter.screenshot("https://example.com", "screenshot.png", %{
        use_windows_browser: true,
        headless: false
      })

  """
  def screenshot(url, path, opts \\ %{}) do
    with_browser(opts, fn page ->
      Playwright.Page.goto(page, url)
      Playwright.Page.screenshot(page, %{path: path})
    end)
  end

  @doc """
  Returns the current version of Playwriter.

  ## Examples

      iex> Playwriter.version()
      "0.0.1"

  """
  def version, do: @version
end
