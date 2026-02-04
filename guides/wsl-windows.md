# WSL-Windows Integration

This guide covers using Playwriter to control visible browsers on Windows from Elixir running in WSL (Windows Subsystem for Linux).

## Why WSL-Windows Integration?

When developing in WSL, you often want to:

- **See the browser** - Watch your automation in real-time for debugging
- **Test visual behavior** - Verify rendering, animations, and UI
- **Debug interactively** - Pause and inspect the browser state
- **Demo to stakeholders** - Show browser automation to non-technical users

The challenge: browsers launched from WSL run headless or in a virtual display. Playwriter solves this by connecting to a Playwright server running natively on Windows.

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                         WSL 2                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Your Elixir Application                │   │
│  │                                                     │   │
│  │   Playwriter.fetch_html("https://example.com",      │   │
│  │     mode: :remote)                                  │   │
│  └───────────────────────┬─────────────────────────────┘   │
│                          │                                 │
│                          │ WebSocket                       │
│                          │ ws://172.x.x.x:3337/            │
└──────────────────────────┼─────────────────────────────────┘
                           │
┌──────────────────────────┼─────────────────────────────────┐
│                          ▼                    Windows      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Playwright Server                      │   │
│  │              (Node.js on Windows)                   │   │
│  └───────────────────────┬─────────────────────────────┘   │
│                          │                                 │
│                          ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Browser Window                         │   │
│  │              (Visible on Windows Desktop)           │   │
│  └─────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────┘
```

## Setup

### 1. Install Node.js on Windows

The Playwright server runs on Node.js. Install Node.js on Windows (not WSL):

```powershell
# Using winget
winget install OpenJS.NodeJS.LTS

# Or download from https://nodejs.org
```

### 2. Install Playwright on Windows

Open PowerShell and install Playwright:

```powershell
# Create a directory for the server
mkdir C:\playwright-server
cd C:\playwright-server

# Initialize and install Playwright
npm init -y
npm install playwright
npx playwright install chromium
```

### 3. Start the Playwright Server

From PowerShell:

```powershell
# Simple start
npx playwright run-server --port 3337

# Or use the provided script from your playwriter project
cd /path/to/playwriter  # Windows path to your project
powershell.exe -File priv/scripts/start_server.ps1
```

The server will output:
```
Listening on ws://0.0.0.0:3337/
```

### 4. Connect from WSL

```elixir
# Auto-discover the server
{:ok, html} = Playwriter.fetch_html("https://example.com", mode: :remote)

# Or specify the endpoint explicitly
{:ok, html} = Playwriter.fetch_html("https://example.com",
  mode: :remote,
  ws_endpoint: "ws://localhost:3337/"
)
```

## Configuration

### Finding the Right Host

Playwriter's discovery mechanism tries multiple hosts:

1. **localhost** - Works when WSL networking is in NAT mode
2. **WSL Gateway IP** - The Windows host IP from WSL's perspective
3. **host.docker.internal** - Docker Desktop's host alias

To find your WSL gateway IP manually:

```bash
# In WSL
cat /etc/resolv.conf | grep nameserver
# Output: nameserver 172.25.160.1
```

### Port Configuration

The default port is 3337. You can change it:

```powershell
# Windows: Start server on different port
npx playwright run-server --port 9222
```

```elixir
# WSL: Connect to that port
Playwriter.fetch_html(url,
  mode: :remote,
  ws_endpoint: "ws://localhost:9222/"
)
```

### Browser Type

```elixir
# Use Firefox instead of Chromium
Playwriter.fetch_html(url,
  mode: :remote,
  browser_type: :firefox
)
```

## Development Workflow

### Interactive Development

Start an IEx session and explore:

```elixir
iex -S mix

# See the browser while you work
{:ok, result} = Playwriter.with_browser([mode: :remote, headless: false], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")

  # Pause here - inspect the browser on Windows
  IO.gets("Press Enter to continue...")

  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

### Debugging Tips

1. **Keep headless: false** - See what's happening
2. **Add pauses** - Use `Process.sleep/1` or `IO.gets/1` to slow down
3. **Take screenshots** - Capture state at key points

```elixir
Playwriter.with_browser([mode: :remote, headless: false], fn ctx ->
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

## Troubleshooting

### "Connection refused" or "Discovery failed"

**Check the server is running:**
```powershell
# On Windows
netstat -an | findstr 3337
```

**Check Windows Firewall:**
- Allow Node.js through Windows Firewall
- Or temporarily disable firewall for testing

**Test connectivity from WSL:**
```bash
# Try to connect
nc -zv localhost 3337
# or
curl -v ws://localhost:3337/
```

### "Browser not visible"

Ensure you're passing `headless: false`:

```elixir
Playwriter.fetch_html(url, mode: :remote, headless: false)
```

### "Wrong browser opens"

Install the browser you want on Windows:

```powershell
npx playwright install firefox
npx playwright install webkit
```

### WSL 1 vs WSL 2

- **WSL 1**: `localhost` should work directly
- **WSL 2**: May need the gateway IP; Playwriter's discovery handles this

Check your WSL version:
```bash
wsl.exe -l -v
```

### Slow performance

- Use headless mode for actual scraping (local transport)
- Remote mode adds network latency
- Consider running the server on the same network segment

## Advanced Configuration

### Environment Variables

Set defaults via environment:

```bash
# In .bashrc or .zshrc
export PLAYWRITER_WS_ENDPOINT="ws://172.25.160.1:3337/"
```

```elixir
# Use in code
endpoint = System.get_env("PLAYWRITER_WS_ENDPOINT")
Playwriter.fetch_html(url, mode: :remote, ws_endpoint: endpoint)
```

### Application Config

Configure in `config/config.exs`:

```elixir
config :playwriter,
  default_mode: :remote,
  default_ws_endpoint: "ws://localhost:3337/",
  default_browser_type: :chromium
```

### Running Server as Windows Service

For persistent development, run the Playwright server as a Windows service or scheduled task that starts on login.

## Next Steps

- [Architecture Overview](architecture.md) - Understand the full system design
- [Function Reference](functions.md) - Complete function documentation
- [Examples](examples.md) - More code examples
