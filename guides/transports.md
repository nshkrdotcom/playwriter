# Transport Layer

Playwriter's transport layer abstracts the communication between your Elixir application and the Playwright browser automation engine. This design enables both local and remote browser control through a unified API.

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

### Limitations

- Browser runs on the same machine as your Elixir app
- In WSL, headless-only (no visible window on Windows)

## Remote Transport

The remote transport (`Playwriter.Transport.Remote`) connects via WebSocket to a Playwright server running elsewhere.

### How It Works

```
Your Application (WSL/Linux/Container)
      │
      ▼
Remote Transport (GenServer)
      │
      ▼ WebSocket
      │
Playwright Server (Windows/Remote Host)
      │
      ▼
Browser (visible on remote desktop)
```

### Usage

```elixir
# Auto-discover server (WSL to Windows)
Playwriter.fetch_html("https://example.com", mode: :remote)

# Explicit endpoint
Playwriter.fetch_html("https://example.com",
  mode: :remote,
  ws_endpoint: "ws://192.168.1.100:3337/"
)
```

### Server Discovery

When using `mode: :remote` without an explicit `ws_endpoint`, Playwriter automatically searches for a running Playwright server:

1. **Ports scanned**: 3337, 3336, 3335, 3334, 9222
2. **Hosts tried**:
   - `localhost`
   - WSL gateway IP (from `/etc/resolv.conf`)
   - `host.docker.internal`

```elixir
# Manual discovery
{:ok, endpoint} = Playwriter.Server.Discovery.discover()
# => {:ok, "ws://172.25.160.1:3337/"}
```

### Starting the Server

On Windows, start the Playwright server:

```powershell
# From PowerShell
cd path/to/playwriter
powershell.exe -File priv/scripts/start_server.ps1
```

Or manually:

```powershell
npx playwright run-server --port 3337
```

### Advantages

- **Visible browsers** - See automation happening in real-time
- **Cross-platform** - Control Windows browsers from WSL/Linux
- **Distributed** - Browser can run on dedicated machines

### Limitations

- Requires running a Playwright server
- Network latency between client and server
- Server must be accessible from client

## Choosing a Transport

| Scenario | Recommended Transport |
|----------|----------------------|
| CI/CD pipelines | Local (headless) |
| Development debugging | Remote (headed) |
| WSL to Windows | Remote |
| Docker containers | Local or Remote |
| Production scraping | Local (headless) |
| E2E test development | Remote (see browser) |

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
# Install Playwright browsers
mix playwright.install
```

**"Browser launch failed"**
```bash
# Ensure dependencies are installed
npx playwright install-deps chromium
```

### Remote Transport Issues

**"Connection refused"**
- Ensure the Playwright server is running on Windows
- Check firewall settings allow the port
- Verify the endpoint URL

**"Discovery failed"**
```elixir
# Check what Discovery finds
Playwriter.Server.Discovery.discover(timeout: 10_000)
```

**"WebSocket timeout"**
- Increase timeout: `Playwriter.fetch_html(url, timeout: 60_000)`
- Check network connectivity between client and server
