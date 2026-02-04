# Getting Started

This guide will help you get up and running with Playwriter in just a few minutes.

## Installation

Add `playwriter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:playwriter, "~> 0.1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

Playwriter will automatically install the Playwright Node.js driver when you first use it.

## Your First Script

Let's fetch some HTML from a website:

```elixir
# Fetch HTML from a URL
{:ok, html} = Playwriter.fetch_html("https://example.com")
IO.puts("Got #{String.length(html)} bytes of HTML")
```

That's it! Playwriter handles all the browser lifecycle management for you.

## Taking Screenshots

Capture a screenshot of any webpage:

```elixir
{:ok, png_data} = Playwriter.screenshot("https://example.com")
File.write!("screenshot.png", png_data)
```

## Interactive Browser Sessions

For more control, use `with_browser/2` to interact with pages:

```elixir
{:ok, title} = Playwriter.with_browser([], fn ctx ->
  # Navigate to a page
  :ok = Playwriter.goto(ctx, "https://example.com")

  # Click a link
  :ok = Playwriter.click(ctx, "a")

  # Get the page content
  {:ok, html} = Playwriter.content(ctx)

  # Return whatever you need
  html
end)
```

The browser is automatically closed when the function completes, even if an error occurs.

## Configuration Options

All functions accept options to customize behavior:

```elixir
# Run with a visible browser window
Playwriter.fetch_html("https://example.com", headless: false)

# Use a specific browser type
Playwriter.fetch_html("https://example.com", browser_type: :firefox)

# Set a custom timeout
Playwriter.fetch_html("https://example.com", timeout: 60_000)
```

## WSL to Windows Integration

If you're running Elixir in WSL and want to see a browser window on Windows:

1. Start the Playwright server on Windows:
   ```powershell
   powershell.exe -File priv/scripts/start_server.ps1
   ```

2. Connect from WSL:
   ```elixir
   Playwriter.fetch_html("https://example.com",
     mode: :remote,
     ws_endpoint: "ws://localhost:3337/"
   )
   ```

See the [WSL-Windows Integration Guide](wsl-windows.md) for detailed setup instructions.

## Next Steps

- [Architecture Overview](architecture.md) - Understand how Playwriter works
- [Function Reference](functions.md) - Complete function documentation
- [Transport Layer](transports.md) - Learn about local vs remote transports
- [Examples](examples.md) - Real-world usage examples
