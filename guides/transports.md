# Transport Layer

Playwriter's transport layer abstracts the communication between your Elixir application and the Playwright browser automation engine. This design enables local, Windows, and remote browser control through a unified API.

## Transport Abstraction

All transports implement `Playwriter.Transport.Behaviour`, ensuring consistent behavior regardless of how you connect to Playwright:

```elixir
@callback start_link(keyword()) :: {:ok, pid()} | {:error, term()}
@callback launch_browser(transport(), browser_type(), keyword()) :: {:ok, guid()}
@callback new_context(transport(), guid(), keyword()) :: {:ok, guid()}
@callback new_page(transport(), guid()) :: {:ok, map()}
@callback goto(transport(), guid(), String.t(), keyword()) :: result()
@callback content(transport(), guid()) :: {:ok, String.t()}
@callback click(transport(), guid(), String.t(), keyword()) :: result()
@callback fill(transport(), guid(), String.t(), String.t(), keyword()) :: result()
@callback screenshot(transport(), guid(), keyword()) :: {:ok, binary()}
@callback close_browser(transport(), guid()) :: :ok
```

## Local Transport

The local transport (`Playwriter.Transport.Local`) wraps `playwright_ex` for direct browser control on the same machine.

### How It Works

```
Your Application
      │
      ▼
Local Transport (GenServer)
      │
      ▼
PlaywrightEx Library
      │
      ▼
Erlang Port
      │
      ▼
Node.js Playwright Driver
      │
      ▼
Browser (Chromium/Firefox/WebKit)
```

### Usage

Local transport is the default when no `mode` option is specified:

```elixir
# These are equivalent
Playwriter.fetch_html("https://example.com")
Playwriter.fetch_html("https://example.com", mode: :local)
```

### Advantages

- **Lower latency** - No network overhead
- **Simpler setup** - No server to run
- **Best for CI/CD** - Headless automation
- **Multiple browsers** - Chromium, Firefox, WebKit

### Limitations

- Browser runs on the same machine as your Elixir app
- In WSL, headless-only (no visible window on Windows)

## Windows Transport

The Windows transport (`Playwriter.Transport.WindowsCmd`) runs Playwright directly on Windows via PowerShell, controlled from WSL.

### How It Works

```
Your Application (WSL)
      │
      ▼
Windows Transport (GenServer)
      │
      ▼ Erlang Port (stdin/stdout)
      │
PowerShell.exe
      │
      ▼
Node.js + Playwright (on Windows)
      │
      ▼
Browser (visible on Windows desktop)
```

### Usage

```elixir
# Visible browser on Windows
Playwriter.fetch_html("https://example.com", mode: :windows)

# Interactive session
Playwriter.with_browser([mode: :windows], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")
  :ok = Playwriter.click(ctx, "button")
  Playwriter.content(ctx)
end)
```

### Setup

One-time installation:

```bash
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install
```

### Advantages

- **Visible browsers** - See automation happening in real-time
- **No network issues** - Bypasses WSL2 Hyper-V firewall completely
- **No server required** - Just works after npm install
- **Best for WSL development** - The recommended mode for WSL users

### Limitations

- Only works from WSL to Windows
- Currently only supports Chromium
- Slightly higher startup latency than local mode

## Remote Transport

The remote transport (`Playwriter.Transport.Remote`) is designed for connecting via WebSocket to a Playwright server running elsewhere.

### Current Status

**Note:** The remote transport is currently non-functional from WSL2 due to Hyper-V firewall blocking WebSocket connections to Windows. Use `:windows` mode instead for WSL-to-Windows automation.

The remote transport returns a helpful error message directing users to `:windows` mode:

```elixir
{:error, {:not_supported, "Use mode: :windows instead..."}} =
  Playwriter.fetch_html(url, mode: :remote)
```

### When Remote Would Be Useful

In non-WSL scenarios where you have network access to a Playwright server:
- Distributed browser automation across machines
- Controlling browsers in cloud environments
- Separating browser execution from application logic

## Choosing a Transport

| Scenario | Recommended Transport |
|----------|----------------------|
| CI/CD pipelines | `:local` (headless) |
| WSL development | `:windows` |
| WSL debugging | `:windows` |
| Docker containers | `:local` |
| Production scraping | `:local` (headless) |
| E2E test development | `:windows` (see browser) |

## Custom Transports

You can implement custom transports for specialized scenarios:

```elixir
defmodule MyApp.CustomTransport do
  @behaviour Playwriter.Transport.Behaviour

  use GenServer

  @impl true
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    # Your initialization logic
    {:ok, %{}}
  end

  @impl Playwriter.Transport.Behaviour
  def launch_browser(transport, browser_type, opts) do
    GenServer.call(transport, {:launch_browser, browser_type, opts})
  end

  # ... implement other callbacks
end
```

Use your custom transport:

```elixir
Playwriter.with_browser([transport_module: MyApp.CustomTransport], fn ctx ->
  # Your automation code
end)
```

## Troubleshooting

### Local Transport Issues

**"playwright_ex driver not found"**
```bash
# Run setup
mix playwriter.setup
```

**"Browser launch failed"**
```bash
# Ensure dependencies are installed
cd deps/playwright/priv/static && npx playwright install-deps chromium
```

### Windows Transport Issues

**"Timeout waiting for transport to start"**
- Ensure Node.js is installed on Windows
- Run the setup script: `powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1 -Install`

**"Cannot find module 'playwright'"**
```powershell
# On Windows, in PowerShell
cd $env:TEMP\playwriter-server
npm install playwright
npx playwright install chromium
```

### Remote Transport Issues

**"not_supported" error**
- Use `mode: :windows` instead when working from WSL
- The remote transport doesn't work from WSL2 due to networking restrictions
