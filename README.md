# Playwriter

A simple HTML fetcher using Playwright for Elixir with CLI interface and session management capabilities.

## Overview

Playwriter is a command-line application that demonstrates browser automation using Playwright for Elixir. It can fetch HTML content from any website with support for different browser modes, authentication headers, and cookie-based session management. The URL is fully configurable, making it suitable for scraping any website.

## Features

- 🌐 **Web Scraping**: Fetch HTML content from any website
- 🔗 **Configurable URLs**: No hardcoded URLs - scrape any site you want
- 🤖 **Browser Automation**: Uses Playwright with Chromium browser
- 🔧 **Multiple Modes**: Headless, GUI, and authentication modes  
- 🍪 **Session Management**: Custom headers and cookies support
- 🧪 **Testing**: Comprehensive test suite included
- 📱 **CLI Interface**: Easy-to-use command-line interface
- ⚡ **JavaScript Support**: Handles dynamic content and JS-heavy sites

## Installation

### Prerequisites

- Elixir 1.18+ 
- Mix build tool
- Internet connection for downloading browser binaries

### Setup

1. **Clone and navigate to the project:**
   ```bash
   git clone <repository-url>
   cd playwriter
   ```

2. **Install dependencies:**
   ```bash
   mix deps.get
   ```

3. **Install Playwright browsers** (Required step):
   ```bash
   mix playwright.install
   ```
   This downloads the necessary browser binaries (Chromium) and system dependencies.

4. **Compile the project:**
   ```bash
   mix compile
   ```

5. **Run tests to verify setup:**
   ```bash
   mix test
   ```

## Usage

### Command Line Interface

```bash
# Basic usage - fetch HTML from google.com (headless mode)
mix run -e "Playwriter.CLI.main([])"

# Fetch HTML from any URL (headless mode)
mix run -e "Playwriter.CLI.main([\"https://example.com\"])"

# Explicit test command with google.com
mix run -e "Playwriter.CLI.main([\"test\"])"

# Test command with custom URL
mix run -e "Playwriter.CLI.main([\"test\", \"https://news.ycombinator.com\"])"

# Show help
mix run -e "Playwriter.CLI.main([\"help\"])"

# GUI mode with google.com (attempts to show browser window)
mix run -e "Playwriter.CLI.main([\"test\", \"--gui\"])"

# GUI mode with custom URL
mix run -e "Playwriter.CLI.main([\"test\", \"--gui\", \"https://example.com\"])"

# Authentication mode with google.com (custom headers and cookies)
mix run -e "Playwriter.CLI.main([\"test\", \"--auth\"])"

# Authentication mode with custom URL
mix run -e "Playwriter.CLI.main([\"test\", \"--auth\", \"https://httpbin.org/headers\"])"
```

### Browser Modes

#### 1. **Headless Mode** (Default)
- Browser runs invisibly in the background
- Fast and efficient for automated tasks
- Works in server environments

#### 2. **GUI Mode**
- Attempts to show browser window
- Useful for debugging and development
- May not work in headless server environments
- Falls back to headless mode if GUI fails

#### 3. **Authentication Mode**
- Demonstrates session management
- Custom HTTP headers
- Cookie-based authentication
- User-Agent spoofing

### URL Flexibility

Playwriter can fetch content from any website:

```bash
# Popular sites
mix run -e "Playwriter.CLI.main([\"https://news.ycombinator.com\"])"
mix run -e "Playwriter.CLI.main([\"https://github.com\"])"
mix run -e "Playwriter.CLI.main([\"https://stackoverflow.com\"])"

# Testing/development sites
mix run -e "Playwriter.CLI.main([\"https://httpbin.org/headers\"])"
mix run -e "Playwriter.CLI.main([\"https://example.com\"])"

# Local development
mix run -e "Playwriter.CLI.main([\"http://localhost:3000\"])"
```

### Programmatic Usage

```elixir
# Basic HTML fetching from any URL
{:ok, html} = Playwriter.fetch_html("https://example.com")
{:ok, html} = Playwriter.fetch_html("https://news.ycombinator.com")
{:ok, html} = Playwriter.fetch_html("https://github.com")

# With custom options for any URL
{:ok, html} = Playwriter.Fetcher.fetch_html("https://httpbin.org/headers", %{
  headless: false,
  headers: %{
    "User-Agent" => "MyBot 1.0",
    "Authorization" => "Bearer token123"
  },
  cookies: [
    %{
      name: "session_id",
      value: "abc123",
      domain: ".httpbin.org",
      path: "/",
      secure: true,
      httpOnly: true
    }
  ]
})
```

## API Reference

### Main Functions

#### `Playwriter.fetch_html/1`
Basic HTML fetching function.

```elixir
{:ok, html} = Playwriter.fetch_html("https://example.com")
```

#### `Playwriter.Fetcher.fetch_html/2`
Advanced HTML fetching with options.

```elixir
{:ok, html} = Playwriter.Fetcher.fetch_html(url, options)
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `headless` | `boolean` | `true` | Run browser in headless mode |
| `devtools` | `boolean` | `false` | Open Developer Tools |
| `headers` | `map` | `%{}` | Custom HTTP headers |
| `cookies` | `list` | `[]` | List of cookie maps |
| `args` | `list` | `[]` | Additional browser arguments |

### Cookie Format

```elixir
%{
  name: "cookie_name",        # Required
  value: "cookie_value",      # Required  
  domain: ".example.com",     # Optional
  path: "/",                  # Optional
  secure: true,               # Optional
  httpOnly: true,             # Optional
  expires: 1234567890.0       # Optional (Unix timestamp)
}
```

## Browser Support

| Browser | Status | Notes |
|---------|--------|-------|
| Chromium | ✅ Supported | Default and only working browser |
| Firefox | ❌ Not implemented | Planned for future releases |
| WebKit | ❌ Not implemented | Planned for future releases |

## Examples

### Basic Web Scraping

```elixir
defmodule MyScraper do
  def get_page_title(url) do
    case Playwriter.fetch_html(url) do
      {:ok, html} ->
        case Regex.run(~r/<title>(.*?)<\/title>/i, html) do
          [_, title] -> {:ok, title}
          _ -> {:error, "No title found"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def scrape_multiple_sites do
    urls = [
      "https://example.com",
      "https://news.ycombinator.com", 
      "https://github.com",
      "https://stackoverflow.com"
    ]
    
    for url <- urls do
      case get_page_title(url) do
        {:ok, title} -> {url, title}
        {:error, _} -> {url, "Failed to get title"}
      end
    end
  end
end

# Usage examples
{:ok, title} = MyScraper.get_page_title("https://example.com")
results = MyScraper.scrape_multiple_sites()
```

### Authentication Example

```elixir
defmodule AuthenticatedScraper do
  def fetch_protected_page(url, auth_token) do
    options = %{
      headless: true,
      headers: %{
        "Authorization" => "Bearer #{auth_token}",
        "User-Agent" => "MyApp/1.0"
      },
      cookies: [
        %{
          name: "session_token",
          value: auth_token,
          domain: URI.parse(url).host,
          path: "/",
          secure: true,
          httpOnly: true
        }
      ]
    }
    
    Playwriter.Fetcher.fetch_html(url, options)
  end
end
```

## Testing

Run the test suite:

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/playwriter_test.exs
```

### Test Coverage

The project includes tests for:
- HTML fetching from various websites (Google.com, example.com, etc.)
- HTML content validation
- Error handling
- Different browser configurations
- URL parsing and domain extraction

## Troubleshooting

### Common Issues

1. **Browser binaries not found**
   ```
   Solution: Run `mix playwright.install` to download browser binaries
   ```

2. **GUI mode not working**
   ```
   - Normal in headless server environments
   - GUI mode automatically falls back to headless mode
   - Ensure you have a display server if running locally
   ```

3. **Permission errors during installation**
   ```
   - The installer may require sudo access for system dependencies
   - This is normal and safe - it installs required libraries
   ```

4. **Function clause errors**
   ```
   - Playwright for Elixir is in alpha - some features may not work
   - Check the error logs for specific API incompatibilities
   ```

### Debug Mode

Enable debug logging by setting log level:

```elixir
# In config/config.exs
config :logger, level: :debug
```

## Project Structure

```
playwriter/
├── lib/
│   ├── playwriter.ex              # Main module
│   └── playwriter/
│       ├── cli.ex                 # CLI interface
│       └── fetcher.ex             # HTML fetching logic
├── test/
│   └── playwriter_test.exs        # Test suite
├── mix.exs                        # Project configuration
└── README.md                      # This file
```

## Configuration

### Application Configuration

```elixir
# config/config.exs
config :playwright, LaunchOptions,
  headless: true,
  devtools: false,
  args: ["--disable-web-security"]

config :logger, level: :info
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MIX_ENV` | Environment (dev/test/prod) | `dev` |
| `PLAYWRIGHT_BROWSERS_PATH` | Custom browser path | Auto-detected |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Install dependencies
mix deps.get

# Install browsers
mix playwright.install

# Run tests
mix test

# Format code
mix format

# Check for issues
mix credo
```

## Known Limitations

1. **Alpha Software**: Playwright for Elixir is in alpha/preview status
2. **Single Browser**: Only Chromium is currently supported
3. **API Compatibility**: Some Playwright features may not be fully implemented
4. **GUI Mode**: Non-headless mode has compatibility issues
5. **Platform Support**: Primarily tested on Linux environments

## Dependencies

- `playwright` (~> 1.49.1-alpha.2) - Browser automation
- `jason` - JSON parsing (transitive dependency)
- `gun` - HTTP client (transitive dependency)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Playwright](https://playwright.dev/) - The browser automation framework
- [Playwright for Elixir](https://github.com/geometerio/playwright-elixir) - The Elixir implementation
- [Elixir](https://elixir-lang.org/) - The programming language

## Support

For issues and questions:
1. Check the [troubleshooting section](#troubleshooting)
2. Review the [Playwright Elixir documentation](https://hexdocs.pm/playwright/)
3. Open an issue on the repository

---

**Note**: This is a demonstration project showing Playwright integration with Elixir. The Playwright for Elixir library is currently in alpha status and may not have full feature parity with other Playwright implementations.

