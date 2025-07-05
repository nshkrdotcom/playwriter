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
  Fetch HTML content from a URL using Playwright.

  This is the main entry point for simple HTML fetching. For more advanced options,
  use `Playwriter.Fetcher.fetch_html/2`.

  ## Parameters

  - `url` - The URL to fetch HTML from

  ## Returns

  - `{:ok, html}` - Success with HTML content as binary
  - `{:error, reason}` - Error with reason

  ## Examples

      # Basic usage
      {:ok, html} = Playwriter.fetch_html("https://example.com")

      # Check if page loaded correctly
      case Playwriter.fetch_html("https://google.com") do
        {:ok, html} when byte_size(html) > 1000 ->
          IO.puts("Successfully fetched page")
        {:ok, html} ->
          IO.puts("Page loaded but seems small")
        {:error, reason} ->
          IO.puts("Failed to fetch")
      end

  """
  def fetch_html(url) do
    Playwriter.Fetcher.fetch_html(url)
  end

  @doc """
  Returns the current version of Playwriter.

  ## Examples

      iex> Playwriter.version()
      "0.0.1"

  """
  def version, do: @version
end
