# Transport Layer

Playwriter's transport layer abstracts the communication between your Elixir application and the Playwright browser automation engine. The local and Windows transports expose the same browser API.

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
playwright_ex (Playwright.*)
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

Select a browser and keep the same setting for setup and runtime. See [WSL–Windows Setup](wsl-windows.md) for the available choices.

```bash
export PLAYWRITER_WINDOWS_CHANNEL=chrome
mix playwriter.setup --mode windows
```

### Advantages

- **Visible browsers** - See automation happening in real-time
- **No network issues** - Bypasses WSL2 Hyper-V firewall completely
- **No server required** - Run the one-time stdio setup
- **Native Windows browser** - The browser process runs on Windows

### Limitations

- Only works from WSL to Windows
- Supports installed Chrome or Edge, or managed Chrome for Testing
- Slightly higher startup latency than local mode

## Remote Transport

The legacy `:remote` WebSocket transport is unsupported. Use `:windows` for a
native Windows browser from WSL.

## Choosing a Transport

| Scenario | Recommended Transport |
|----------|----------------------|
| CI/CD pipelines | `:local` (headless) |
| Visible Chrome for Testing through WSLg | `:local` with `headless: false` |
| Native Windows browser from WSL | `:windows` |
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
mix playwriter.setup --with-deps
```

### Windows Transport Issues

**"Timeout waiting for transport to start"**
- Ensure Node.js is installed on Windows
- Check the selected browser and driver with `mix playwriter.setup --mode windows --browser chrome --check` (substitute your selected browser).

For missing or stale driver assets, see [WSL–Windows Setup](wsl-windows.md).

### Remote Transport Issues

**"not_supported" error**
- Use `mode: :windows` instead when working from WSL
- The legacy remote transport is unsupported
