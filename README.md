<p align="center">
  <img src="assets/playwriter.svg" alt="Playwriter" width="200" />
</p>

<h1 align="center">Playwriter</h1>

<p align="center">
  <strong>Elixir browser automation for developers who work in WSL but need visible Windows browsers</strong>
</p>

<p align="center">
  <a href="https://hex.pm/packages/playwriter"><img src="https://img.shields.io/hexpm/v/playwriter.svg" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/playwriter"><img src="https://img.shields.io/badge/docs-hexdocs-blue.svg" alt="Documentation"></a>
  <a href="https://github.com/nshkrdotcom/playwriter/blob/main/LICENSE"><img src="https://img.shields.io/hexpm/l/playwriter.svg" alt="License"></a>
</p>

---

## The Problem

You're developing in WSL. You need to automate a browser. But when you launch Chromium from WSL, you get a headless process or an invisible window buried in a virtual display. You can't see what's happening. You can't debug visually. You can't demo to anyone.

## The Solution

Playwriter runs Playwright directly on Windows via PowerShell, controlled from your Elixir code in WSL. The browser opens on your Windows desktop where you can see it. Click buttons, fill forms, take screenshots—all visible in real-time. No server setup, no firewall rules, no network configuration.

```elixir
# This browser opens on your Windows desktop - visible!
{:ok, html} = Playwriter.fetch_html("https://example.com", mode: :windows)
```

## Quick Start

### Installation

Add to your `mix.exs`:

```elixir
def deps do
  [{:playwriter, "~> 0.1.0"}]
end
```

Then run setup:

```bash
mix deps.get
mix playwriter.setup
```

### Basic Usage (Local/Headless)

```elixir
# Fetch HTML from a page
{:ok, html} = Playwriter.fetch_html("https://example.com")

# Take a screenshot
{:ok, png} = Playwriter.screenshot("https://example.com")
File.write!("screenshot.png", png)
```

### WSL to Windows (Visible Browser)

**One-time setup on Windows:**

```powershell
# Run from WSL - installs Playwright in Windows temp directory
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install
```

**Use from Elixir:**

```elixir
{:ok, html} = Playwriter.fetch_html("https://example.com", mode: :windows)
```

A browser window opens on your Windows desktop. You watch it navigate. You see the page load.

## Interactive Sessions

For complex workflows, use `with_browser/2`:

```elixir
{:ok, result} = Playwriter.with_browser([mode: :windows], fn ctx ->
  # Navigate
  :ok = Playwriter.goto(ctx, "https://example.com/login")

  # Fill form
  :ok = Playwriter.fill(ctx, "#username", "myuser")
  :ok = Playwriter.fill(ctx, "#password", "secret")

  # Click submit
  :ok = Playwriter.click(ctx, "button[type=submit]")

  # Wait and get result
  Process.sleep(1000)
  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

The browser stays open for the entire session. You see every action happen.

## Three Modes

| Mode | Use Case | Browser Location |
|------|----------|------------------|
| `:local` (default) | CI/CD, headless scraping | Same machine as Elixir |
| `:windows` | WSL development, debugging, demos | Windows desktop (visible) |
| `:remote` | Distributed automation (advanced) | Remote server |

```elixir
# Local mode - fast, headless
Playwriter.fetch_html(url)
Playwriter.fetch_html(url, mode: :local)

# Windows mode - visible on Windows desktop (recommended for WSL)
Playwriter.fetch_html(url, mode: :windows)
```

## Configuration

```elixir
Playwriter.fetch_html(url,
  mode: :windows,                   # :local, :windows, or :remote
  headless: false,                  # true for invisible, false to watch
  browser_type: :chromium,          # :chromium (only for :windows mode)
  timeout: 30_000                   # milliseconds
)
```

## Architecture

```
┌───────────────────────────────────────────────────┐
│                     WSL                           │
│  ┌─────────────────────────────────────────────┐  │
│  │         Your Elixir Application             │  │
│  │                                             │  │
│  │  Playwriter.fetch_html(url, mode: :windows) │  │
│  └─────────────────────┬───────────────────────┘  │
│                        │ stdin/stdout              │
│                        │ (via PowerShell)          │
└────────────────────────┼──────────────────────────┘
                         │
┌────────────────────────┼─────────────────────────┐
│                        ▼           Windows       │
│  ┌────────────────────────────────────────────┐  │
│  │         Node.js + Playwright               │  │
│  └─────────────────────┬──────────────────────┘  │
│                        │                         │
│  ┌────────────────────────────────────────────┐  │
│  │              Browser Window                │  │
│  │         (Visible on your desktop)          │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

The `:windows` mode bypasses WSL2's Hyper-V networking entirely by communicating via PowerShell stdin/stdout.

## Documentation

- **[Getting Started](guides/getting-started.md)** - Installation and first steps
- **[Architecture](guides/architecture.md)** - How Playwriter works
- **[Transport Layer](guides/transports.md)** - Local, Windows, and Remote modes
- **[WSL-Windows Integration](guides/wsl-windows.md)** - Detailed setup guide
- **[Function Reference](guides/functions.md)** - Complete function documentation
- **[Examples](guides/examples.md)** - Real-world usage patterns
- **[Troubleshooting](guides/troubleshooting.md)** - Common issues and fixes

## When to Use Playwriter

**Use Playwriter when:**
- You develop in WSL but need to see browsers on Windows
- You're debugging web scraping and need visual feedback
- You want to demo browser automation to stakeholders
- You need to interact with sites that require JavaScript rendering

**Use something else when:**
- You only need headless automation (use `playwright_ex` directly)
- You're not in a WSL environment
- You need maximum performance (local mode is faster)

## Contributing

Issues and PRs welcome at [github.com/nshkrdotcom/playwriter](https://github.com/nshkrdotcom/playwriter).

## License

MIT License. See [LICENSE](LICENSE) for details.
