# WSL-Windows Integration

This guide covers using Playwriter to control visible browsers on Windows from Elixir running in WSL (Windows Subsystem for Linux).

## Why WSL-Windows Integration?

When developing in WSL, you often want to:

- **See the browser** - Watch your automation in real-time for debugging
- **Test visual behavior** - Verify rendering, animations, and UI
- **Debug interactively** - Pause and inspect the browser state
- **Demo to stakeholders** - Show browser automation to non-technical users

The challenge: browsers launched from WSL run headless or in a virtual display, and WSL2's Hyper-V networking blocks most connection attempts to Windows. Playwriter solves this with the `:windows` mode.

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                         WSL 2                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Your Elixir Application                │   │
│  │                                                     │   │
│  │   Playwriter.fetch_html("https://example.com",      │   │
│  │     mode: :windows)                                 │   │
│  └───────────────────────┬─────────────────────────────┘   │
│                          │                                 │
│                          │ Erlang Port                     │
│                          │ (stdin/stdout via PowerShell)   │
└──────────────────────────┼─────────────────────────────────┘
                           │
┌──────────────────────────┼─────────────────────────────────┐
│                          ▼                    Windows      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              PowerShell + Node.js                   │   │
│  │              (runs Playwright directly)             │   │
│  └───────────────────────┬─────────────────────────────┘   │
│                          │                                 │
│                          ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Browser Window                         │   │
│  │              (Visible on Windows Desktop)           │   │
│  └─────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────┘
```

The `:windows` mode bypasses WSL2's Hyper-V firewall entirely by communicating via PowerShell stdin/stdout instead of network sockets.

## Setup

### 1. Install Node.js on Windows

The Playwright driver runs on Node.js. Install Node.js on Windows (not WSL):

```powershell
# Using winget
winget install OpenJS.NodeJS.LTS

# Or download from https://nodejs.org
```

### 2. Install Playwright on Windows

Run the setup script from WSL:

```bash
# One-time setup - installs Playwright in Windows temp directory
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install
```

This creates `%TEMP%\playwriter-server` on Windows with Playwright installed.

### 3. Use from Elixir

```elixir
# Simple fetch
{:ok, html} = Playwriter.fetch_html("https://example.com", mode: :windows)

# Screenshot
{:ok, png} = Playwriter.screenshot("https://example.com", mode: :windows)
File.write!("screenshot.png", png)

# Full browser control
Playwriter.with_browser([mode: :windows], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")
  :ok = Playwriter.fill(ctx, "input[name=q]", "search term")
  :ok = Playwriter.click(ctx, "button[type=submit]")
  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

## Development Workflow

### Interactive Development

Start an IEx session and explore:

```elixir
iex -S mix

# See the browser while you work
{:ok, result} = Playwriter.with_browser([mode: :windows], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")

  # Pause here - inspect the browser on Windows
  IO.gets("Press Enter to continue...")

  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

### Debugging Tips

1. **Use `:windows` mode** - See what's happening in real-time
2. **Add pauses** - Use `Process.sleep/1` or `IO.gets/1` to slow down
3. **Take screenshots** - Capture state at key points

```elixir
Playwriter.with_browser([mode: :windows], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")

  # Screenshot before clicking
  {:ok, before} = Playwriter.screenshot(ctx)
  File.write!("before.png", before)

  :ok = Playwriter.click(ctx, "button.submit")
  Process.sleep(1000)  # Wait for navigation

  # Screenshot after
  {:ok, after_shot} = Playwriter.screenshot(ctx)
  File.write!("after.png", after_shot)
end)
```

## How It Works

The `:windows` mode uses the `Playwriter.Transport.WindowsCmd` transport which:

1. Writes a Node.js script to `%TEMP%\playwriter-server\transport.js` on Windows
2. Launches PowerShell with that script via Erlang Ports
3. Communicates via JSON messages over stdin/stdout
4. The Node.js script controls Playwright/Chromium on Windows

This approach completely bypasses networking, avoiding all WSL2 Hyper-V firewall issues.

## Troubleshooting

### "Playwright not installed" or "Cannot find module 'playwright'"

Run the setup script with `-Install`:

```bash
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install
```

Or manually install on Windows:

```powershell
cd $env:TEMP\playwriter-server
npm install playwright
npx playwright install chromium
```

### "Timeout waiting for transport to start"

Check that:
1. Node.js is installed on Windows and in PATH
2. Playwright is installed in `%TEMP%\playwriter-server`

Test manually:

```bash
# From WSL
powershell.exe -Command "cd $env:TEMP\playwriter-server; node -e 'console.log(require(\"playwright\").chromium)'"
```

### "Browser closes immediately"

Make sure you're not letting the session close. Use `with_browser` to keep the browser open:

```elixir
Playwriter.with_browser([mode: :windows], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")
  Process.sleep(5000)  # Keep browser open for 5 seconds
  :ok
end)
```

### "PowerShell execution policy error"

Always run with `-ExecutionPolicy Bypass`:

```bash
powershell.exe -ExecutionPolicy Bypass -File script.ps1
```

### Checking Windows User Detection

The transport detects your Windows username from `/mnt/c/Users/`. If it picks the wrong user:

```elixir
# Check what user is detected
File.ls!("/mnt/c/Users")
|> Enum.reject(&(&1 in ["Public", "Default", "Default User", "All Users", "desktop.ini"]))
```

## Comparison: Windows Mode vs Remote Mode

| Feature | `:windows` mode | `:remote` mode |
|---------|----------------|----------------|
| Setup required | Just npm install | Run a server |
| Network issues | None (stdin/stdout) | WSL2 firewall blocks it |
| Performance | Good | Slightly faster |
| WSL2 compatible | Yes | No (blocked by Hyper-V) |
| Recommended for WSL | **Yes** | No |

Use `:windows` mode for WSL-to-Windows browser automation. The `:remote` mode exists for other distributed scenarios but doesn't work reliably from WSL2.

## Next Steps

- [Architecture Overview](architecture.md) - Understand the full system design
- [Function Reference](functions.md) - Complete function documentation
- [Examples](examples.md) - More code examples
