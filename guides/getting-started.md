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

## Choose Your Mode

Playwriter supports two modes of operation:

| Mode | Use Case | Setup Required |
|------|----------|----------------|
| **Local** | CI/CD, headless scraping, native Linux | `mix playwriter.setup` |
| **Remote** | WSL-to-Windows, visible browsers, debugging | Windows Playwright server |

## Quick Start: Local Mode

For headless browser automation on your local machine:

```bash
# One-time setup: install Playwright
mix playwriter.setup
```

Then run an example:

```bash
mix run examples/fetch_html.exs --local
```

Or in your code:

```elixir
{:ok, html} = Playwriter.fetch_html("https://example.com")
```

## Quick Start: Remote Mode (WSL to Windows)

To see browsers on your Windows desktop from WSL:

**1. Start the server on Windows:**

```powershell
powershell.exe -File priv/scripts/start_server.ps1
```

**2. Run from WSL:**

```bash
mix run examples/fetch_html.exs --remote
```

Or in your code:

```elixir
{:ok, html} = Playwriter.fetch_html("https://example.com", mode: :remote)
```

A browser window will open on Windows!

## Running Examples

All examples support both modes with auto-detection:

```bash
# Auto-detect available mode (tries remote first, then local)
mix run examples/fetch_html.exs

# Force local mode
mix run examples/fetch_html.exs --local

# Force remote mode
mix run examples/fetch_html.exs --remote

# Specify endpoint for remote
mix run examples/fetch_html.exs --remote --endpoint ws://localhost:3337/
```

Available examples:
- `examples/fetch_html.exs` - Fetch HTML content
- `examples/screenshot.exs` - Take screenshots
- `examples/interaction.exs` - Form filling and clicking
- `examples/windows_browser.exs` - WSL-to-Windows demo (remote only)

## Setup Commands

### Local Mode Setup

```bash
# Install Playwright and Chromium
mix playwriter.setup

# Install a different browser
mix playwriter.setup --browser firefox

# Install all browsers
mix playwriter.setup --browser all
```

### Remote Mode Setup

On Windows, you need Node.js and Playwright:

```powershell
# Install Node.js (if not already installed)
winget install OpenJS.NodeJS.LTS

# Create server directory
mkdir C:\playwright-server
cd C:\playwright-server
npm init -y
npm install playwright
npx playwright install chromium
```

Then start the server:

```powershell
npx playwright run-server --port 3337
```

Or use the provided script:

```powershell
powershell.exe -File priv/scripts/start_server.ps1
```

## Your First Script

### Fetching HTML

```elixir
# Local mode (default)
{:ok, html} = Playwriter.fetch_html("https://example.com")

# Remote mode (visible on Windows)
{:ok, html} = Playwriter.fetch_html("https://example.com", mode: :remote)

IO.puts("Got #{String.length(html)} bytes of HTML")
```

### Taking Screenshots

```elixir
{:ok, png_data} = Playwriter.screenshot("https://example.com")
File.write!("screenshot.png", png_data)
```

### Interactive Sessions

For complex workflows, use `with_browser/2`:

```elixir
{:ok, result} = Playwriter.with_browser([mode: :remote], fn ctx ->
  # Navigate
  :ok = Playwriter.goto(ctx, "https://example.com")

  # Click a link
  :ok = Playwriter.click(ctx, "a")

  # Get content
  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

The browser is automatically closed when the function completes, even if an error occurs.

## Configuration Options

All functions accept options to customize behavior:

```elixir
Playwriter.fetch_html("https://example.com",
  mode: :local,           # :local or :remote
  headless: false,        # show browser window
  browser_type: :firefox, # :chromium, :firefox, :webkit
  timeout: 60_000         # milliseconds
)
```

## Troubleshooting

### "Playwright executable not found"

Run the setup task:

```bash
mix playwriter.setup
```

### "No Playwright server found"

Start the Windows server:

```powershell
powershell.exe -File priv/scripts/start_server.ps1
```

### Examples fail silently

Run with explicit mode to see detailed errors:

```bash
mix run examples/fetch_html.exs --local
# or
mix run examples/fetch_html.exs --remote
```

## Next Steps

- [Architecture Overview](architecture.md) - Understand how Playwriter works
- [Function Reference](functions.md) - Complete function documentation
- [Transport Layer](transports.md) - Learn about local vs remote transports
- [WSL-Windows Integration](wsl-windows.md) - Detailed remote mode setup
- [Examples](examples.md) - Real-world usage examples
- [Troubleshooting](troubleshooting.md) - Common issues and fixes
