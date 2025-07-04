defmodule Playwriter.CLI do
  @moduledoc """
  CLI interface for Playwriter
  """

  def main(args) do
    case args do
      ["test"] ->
        test_url("https://google.com")
      ["test", url] ->
        test_url(url)
      ["test", "--gui"] ->
        test_url_gui("https://google.com")
      ["test", "--gui", url] ->
        test_url_gui(url)
      ["test", "--auth"] ->
        test_url_with_auth("https://google.com")
      ["test", "--auth", url] ->
        test_url_with_auth(url)
      ["help"] ->
        show_help()
      [] ->
        test_url("https://google.com")
      [url] when is_binary(url) ->
        test_url(url)
      _ ->
        IO.puts("Invalid command. Use 'help' for usage information.")
        System.halt(1)
    end
  end

  defp test_url(url) do
    IO.puts("Testing HTML fetch from #{url}...")
    
    case Playwriter.Fetcher.fetch_html(url, %{headless: true}) do
      {:ok, html} ->
        IO.puts("Successfully fetched HTML from #{url}")
        IO.puts("HTML length: #{String.length(html)} characters")
        IO.puts("Title found: #{extract_title(html)}")
      {:error, reason} ->
        IO.puts("Error fetching HTML: #{reason}")
        System.halt(1)
    end
  end

  defp extract_title(html) do
    case Regex.run(~r/<title>(.*?)<\/title>/i, html) do
      [_, title] -> title
      _ -> "No title found"
    end
  end

  defp test_url_gui(url) do
    IO.puts("Testing HTML fetch from #{url} with GUI browser...")
    IO.puts("Note: GUI mode may not work in headless environments or with current alpha version")
    
    # Try GUI mode, but fall back to headless if it fails
    case Playwriter.Fetcher.fetch_html(url, %{headless: false}) do
      {:ok, html} ->
        IO.puts("Successfully fetched HTML from #{url} (GUI mode)")
        IO.puts("HTML length: #{String.length(html)} characters")
        IO.puts("Title found: #{extract_title(html)}")
      {:error, reason} ->
        IO.puts("GUI mode failed: #{reason}")
        IO.puts("Falling back to headless mode...")
        case Playwriter.Fetcher.fetch_html(url, %{headless: true}) do
          {:ok, html} ->
            IO.puts("Successfully fetched HTML from #{url} (fallback headless)")
            IO.puts("HTML length: #{String.length(html)} characters")
            IO.puts("Title found: #{extract_title(html)}")
          {:error, reason2} ->
            IO.puts("Error fetching HTML: #{reason2}")
            System.halt(1)
        end
    end
  end

  defp test_url_with_auth(url) do
    IO.puts("Testing HTML fetch from #{url} with authentication headers...")
    
    # Extract domain for cookies
    domain = case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> ".#{host}"
      _ -> ".example.com"
    end
    
    opts = %{
      headless: true,
      headers: %{
        "User-Agent" => "Playwriter Bot 1.0",
        "Authorization" => "Bearer fake-token"
      },
      cookies: [
        %{
          name: "session_id",
          value: "abc123",
          domain: domain,
          path: "/",
          secure: true,
          httpOnly: true
        }
      ]
    }
    
    case Playwriter.Fetcher.fetch_html(url, opts) do
      {:ok, html} ->
        IO.puts("Successfully fetched HTML from #{url} (with auth)")
        IO.puts("HTML length: #{String.length(html)} characters")
        IO.puts("Title found: #{extract_title(html)}")
      {:error, reason} ->
        IO.puts("Error fetching HTML: #{reason}")
        System.halt(1)
    end
  end

  defp show_help do
    IO.puts("""
    Playwriter - A simple HTML fetcher using Playwright

    Usage:
      playwriter                    # Test fetching HTML from google.com (headless)
      playwriter <url>              # Fetch HTML from any URL (headless)
      playwriter test               # Test fetching HTML from google.com (headless)
      playwriter test <url>         # Fetch HTML from specific URL (headless)
      playwriter test --gui         # Test fetching with GUI browser from google.com
      playwriter test --gui <url>   # Fetch with GUI browser from specific URL
      playwriter test --auth        # Test fetching with auth from google.com
      playwriter test --auth <url>  # Fetch with auth from specific URL
      playwriter help               # Show this help message

    Examples:
      playwriter https://example.com
      playwriter test --gui https://news.ycombinator.com
      playwriter test --auth https://httpbin.org/headers

    Browser Modes:
      - Headless (default): Browser runs invisibly in background
      - GUI mode: Browser window opens visibly (good for debugging)
      - Auth mode: Demonstrates session management with cookies/headers

    Note: GUI mode may not work in headless server environments.
    """)
  end
end