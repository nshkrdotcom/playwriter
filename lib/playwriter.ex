defmodule Playwriter do
  @moduledoc """
  Playwriter - A simple HTML fetcher using Playwright for Elixir.
  
  This application provides a CLI interface to fetch HTML content from web pages
  using Playwright browser automation.
  """

  @doc """
  Fetch HTML content from a URL using Playwright.

  ## Examples

      iex> {:ok, html} = Playwriter.fetch_html("https://example.com")
      iex> is_binary(html) and String.contains?(html, "Example Domain")
      true

  """
  def fetch_html(url) do
    Playwriter.Fetcher.fetch_html(url)
  end
end
