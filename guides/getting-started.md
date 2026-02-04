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

Playwriter supports three modes of operation:

| Mode | Use Case | Setup Required |
|------|----------|----------------|
| **Local** | CI/CD, headless scraping, native Linux | `mix playwriter.setup` |
| **Windows** | WSL-to-Windows, visible browsers, debugging | One-time npm install |
| **Remote** | Distributed automation (non-WSL only) | Playwright server |

## Quick Start: Local Mode

For headless browser automation on your local machine:

```bash
# One-time setup: install Playwright
mix playwriter.setup
```

Then in your code:

```elixir
{:ok, html} = Playwriter.fetch_html("https://example.com")
```

## Quick Start: Windows Mode (WSL to Windows)

**Recommended for WSL users.** See visible browsers on your Windows desktop:

**1. One-time setup (installs Playwright on Windows):**

```bash
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install
```

**2. Use from Elixir:**

```elixir
{:ok, html} = Playwriter.fetch_html("https://example.com", mode: :windows)
```

A browser window will open on Windows!

## Running Examples

```bash
# Local mode (headless)
mix run examples/fetch_html.exs --local

# Windows mode (visible browser on Windows)
mix run examples/windows_mode.exs
```

Available examples:
- `examples/fetch_html.exs` - Fetch HTML content
- `examples/screenshot.exs` - Take screenshots
- `examples/interaction.exs` - Form filling and clicking
- `examples/windows_mode.exs` - WSL-to-Windows demo

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

### Windows Mode Setup

On Windows, you need Node.js and Playwright installed in `%TEMP%\playwriter-server`:

```bash
# From WSL - runs setup on Windows
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install
```

Or manually on Windows:

```powershell
# Install Node.js (if not already installed)
winget install OpenJS.NodeJS.LTS

# Create and setup server directory
cd $env:TEMP
mkdir playwriter-server
cd playwriter-server
npm init -y
npm install playwright
npx playwright install chromium
```

## Your First Script

### Fetching HTML

```elixir
# Local mode (default, headless)
{:ok, html} = Playwriter.fetch_html("https://example.com")

# Windows mode (visible on Windows desktop)
{:ok, html} = Playwriter.fetch_html("https://example.com", mode: :windows)

IO.puts("Got #{byte_size(html)} bytes of HTML")
```

### Taking Screenshots

```elixir
# Local (headless)
{:ok, png_data} = Playwriter.screenshot("https://example.com")
File.write!("screenshot.png", png_data)

# Windows (visible)
{:ok, png_data} = Playwriter.screenshot("https://example.com", mode: :windows)
File.write!("screenshot.png", png_data)
```

### Interactive Sessions

For complex workflows, use `with_browser/2`:

```elixir
{:ok, result} = Playwriter.with_browser([mode: :windows], fn ctx ->
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
  mode: :windows,         # :local, :windows, or :remote
  headless: false,        # show browser window (local mode only)
  browser_type: :chromium,# :chromium, :firefox, :webkit (local mode)
  timeout: 60_000         # milliseconds
)
```

## Troubleshooting

### "Playwright executable not found"

Run the setup task:

```bash
mix playwriter.setup
```

### "Timeout waiting for transport" (Windows mode)

Ensure Playwright is installed on Windows:

```bash
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install
```

### "Cannot find module 'playwright'" (Windows mode)

Manually install on Windows:

```powershell
cd $env:TEMP\playwriter-server
npm install playwright
npx playwright install chromium
```

## Next Steps

- [Architecture Overview](architecture.md) - Understand how Playwriter works
- [Function Reference](functions.md) - Complete function documentation
- [Transport Layer](transports.md) - Learn about local, windows, and remote transports
- [WSL-Windows Integration](wsl-windows.md) - Detailed Windows mode setup
- [Examples](examples.md) - Real-world usage examples
- [Troubleshooting](troubleshooting.md) - Common issues and fixes
