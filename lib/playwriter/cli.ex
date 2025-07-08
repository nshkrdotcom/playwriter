defmodule Playwriter.CLI do
  @moduledoc """
  CLI interface for Playwriter
  """

  def main(args) do
    case args do
      ["--list-profiles"] ->
        IO.puts("DEBUG: Matched --list-profiles pattern")
        list_chrome_profiles()

      ["--windows-browser", "--list-profiles"] ->
        list_chrome_profiles()

      ["--windows-browser", "--profile", profile_name] ->
        test_windows_browser_with_profile("https://google.com", :chromium, profile_name)

      ["--windows-browser", "--profile", profile_name, url] ->
        test_windows_browser_with_profile(url, :chromium, profile_name)

      ["--windows-browser"] ->
        test_windows_browser("https://google.com")

      ["--windows-browser", url] ->
        test_windows_browser(url)

      ["--windows-firefox"] ->
        test_windows_browser("https://google.com", :firefox)

      ["--windows-firefox", url] ->
        test_windows_browser(url, :firefox)

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
        case String.starts_with?(url, "--") do
          true ->
            IO.puts("Invalid command. Use 'help' for usage information.")
            System.halt(1)

          false ->
            test_url(url)
        end

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
    domain =
      case URI.parse(url) do
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

  defp test_windows_browser(url, browser_type \\ :chromium) do
    IO.puts("Testing HTML fetch from #{url} using Windows #{browser_type} browser...")
    IO.puts("Connecting to Windows browser via WebSocket...")

    opts = %{
      use_windows_browser: true,
      browser_type: browser_type,
      # Windows browsers will show UI
      headless: false
    }

    case Playwriter.Fetcher.fetch_html(url, opts) do
      {:ok, html} ->
        IO.puts("Successfully fetched HTML from #{url} (Windows #{browser_type})")
        IO.puts("HTML length: #{String.length(html)} characters")
        IO.puts("Title found: #{extract_title(html)}")

      {:error, reason} ->
        IO.puts("Error fetching HTML: #{reason}")
        IO.puts("\nTroubleshooting tips:")
        IO.puts("1. Make sure Playwright server is running on Windows")
        IO.puts("2. Run: ./start_true_headed_server.sh")
        IO.puts("3. Check Windows Firewall settings")
        System.halt(1)
    end
  end

  defp test_windows_browser_with_profile(url, browser_type, profile_name) do
    IO.puts(
      "Testing HTML fetch from #{url} using Windows #{browser_type} browser with profile '#{profile_name}'..."
    )

    IO.puts("Connecting to Windows browser via WebSocket...")

    opts = %{
      use_windows_browser: true,
      browser_type: browser_type,
      headless: false,
      chrome_profile: profile_name
    }

    case Playwriter.Fetcher.fetch_html(url, opts) do
      {:ok, html} ->
        IO.puts(
          "Successfully fetched HTML from #{url} (Windows #{browser_type} with profile '#{profile_name}')"
        )

        IO.puts("HTML length: #{String.length(html)} characters")
        IO.puts("Title found: #{extract_title(html)}")

      {:error, reason} ->
        IO.puts("Error fetching HTML: #{reason}")
        IO.puts("\nTroubleshooting tips:")
        IO.puts("1. Make sure Playwright server is running on Windows")
        IO.puts("2. Run: ./start_true_headed_server.sh")
        IO.puts("3. Check that profile '#{profile_name}' exists")
        IO.puts("4. Use --list-profiles to see available profiles")
        System.halt(1)
    end
  end

  defp list_chrome_profiles do
    IO.puts("Available Chrome profiles on Windows:")

    try do
      # Get Chrome user data directory
      case System.cmd("powershell.exe", [
             "-Command",
             "$env:LOCALAPPDATA + '\\Google\\Chrome\\User Data'"
           ]) do
        {chrome_path, 0} ->
          chrome_path = String.trim(chrome_path)
          IO.puts("Chrome data directory: #{chrome_path}")

          # List profile directories
          case System.cmd("powershell.exe", [
                 "-Command",
                 "Get-ChildItem '#{chrome_path}' -Directory | Where-Object {$_.Name -match '^(Default|Profile )' -or $_.Name -eq 'Profile 1'} | ForEach-Object {\"$($_.Name) - $($_.FullName)\"}"
               ]) do
            {output, 0} ->
              profiles =
                output
                |> String.split("\n")
                |> Enum.map(&String.trim/1)
                |> Enum.filter(&(&1 != ""))

              if Enum.empty?(profiles) do
                IO.puts("No Chrome profiles found.")
              else
                Enum.each(profiles, fn profile ->
                  IO.puts("  - #{profile}")
                end)
              end

            _ ->
              IO.puts("Could not list Chrome profile directories")
          end

        _ ->
          IO.puts("Could not find Chrome user data directory")
      end
    rescue
      error ->
        IO.puts("Error listing Chrome profiles: #{inspect(error)}")
    end
  end

  defp show_help do
    IO.puts("""
    Playwriter v0.0.1 - Cross-Platform Browser Automation for Elixir
    By NSHkr (https://github.com/nshkrdotcom/playwriter)

    Usage:
      playwriter                    # Test fetching HTML from google.com (headless)
      playwriter <url>              # Fetch HTML from any URL (headless)
      playwriter test               # Test fetching HTML from google.com (headless)
      playwriter test <url>         # Fetch HTML from specific URL (headless)
      playwriter test --gui         # Test fetching with GUI browser from google.com
      playwriter test --gui <url>   # Fetch with GUI browser from specific URL
      playwriter test --auth        # Test fetching with auth from google.com
      playwriter test --auth <url>  # Fetch with auth from specific URL
      playwriter --windows-browser  # Use Windows Chrome browser from WSL
      playwriter --windows-browser <url>  # Use Windows Chrome for specific URL
      playwriter --windows-browser --profile <name>  # Use specific Chrome profile
      playwriter --windows-browser --profile <name> <url>  # Use profile for specific URL
      playwriter --list-profiles    # List available Chrome profiles
      playwriter --windows-firefox  # Use Windows Firefox browser from WSL
      playwriter --windows-firefox <url>  # Use Windows Firefox for specific URL
      playwriter help               # Show this help message

    Examples:
      playwriter https://example.com
      playwriter test --gui https://news.ycombinator.com
      playwriter test --auth https://httpbin.org/headers
      playwriter --windows-browser https://google.com
      playwriter --windows-browser --profile "Default" https://facebook.com
      playwriter --list-profiles
      playwriter --windows-firefox https://mozilla.org

    Browser Modes:
      - Headless (default): Browser runs invisibly in background
      - GUI mode: Browser window opens visibly (good for debugging)
      - Auth mode: Demonstrates session management with cookies/headers
      - Windows browser: Use Windows Chrome/Firefox from WSL (requires setup)

    Windows Browser Setup:
      1. Run: ./start_true_headed_server.sh
      2. This starts a headed Playwright server on Windows
      3. The server allows WSL to control visible Windows browsers

    Installation:
      Add {:playwriter, "~> 0.0.1"} to your mix.exs dependencies

    Documentation:
      https://hexdocs.pm/playwriter

    Repository:
      https://github.com/nshkrdotcom/playwriter

    Note: GUI mode may not work in headless server environments.
    """)
  end
end
