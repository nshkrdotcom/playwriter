# Architecture Overview

Playwriter is built on a clean, modular architecture that separates concerns and enables flexible deployment scenarios.

## High-Level Design

```
┌────────────────────────────────────────────────────────────────┐
│                         Your Application                       │
└─────────────────────────────┬──────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                          Playwriter                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Public API (Playwriter module)             │   │
│  │    with_browser/2  fetch_html/2  screenshot/2  etc.     │   │
│  └─────────────────────────────┬───────────────────────────┘   │
│                                │                               │
│  ┌─────────────────────────────▼───────────────────────────┐   │
│  │              Browser Session (GenServer)                │   │
│  │         Manages browser lifecycle and pages             │   │
│  └─────────────────────────────┬───────────────────────────┘   │
│                                │                               │
│  ┌─────────────────────────────▼───────────────────────────┐   │
│  │                   Transport Layer                       │   │
│  │  ┌──────────────────┐    ┌────────────────────────────┐ │   │
│  │  │  Local Transport │    │   Remote Transport         │ │   │
│  │  │  (playwright_ex) │    │   (WebSocket to Windows)   │ │   │
│  │  └──────────────────┘    └────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Public API (`Playwriter`)

The main module provides a simple, composable interface:

- **`with_browser/2`** - Execute a function with a managed browser session
- **`fetch_html/2`** - Convenience wrapper for fetching page content
- **`screenshot/2`** - Convenience wrapper for taking screenshots
- **Context operations** - `goto/3`, `content/1`, `click/3`, `fill/4`

### 2. Browser Session (`Playwriter.Browser.Session`)

A GenServer that manages the complete browser lifecycle:

- Starts and configures transports
- Launches browsers and creates contexts
- Manages pages and their frames
- Handles cleanup on termination

```elixir
# Session state structure
%Playwriter.Browser.Session{
  transport: pid(),           # Transport process
  transport_module: module(), # Local or Remote
  browser_guid: String.t(),   # Playwright browser ID
  contexts: %{},              # Active browser contexts
  pages: %{}                  # Active pages
}
```

### 3. Transport Layer

The transport layer abstracts communication with Playwright:

#### Local Transport (`Playwriter.Transport.Local`)

- Wraps `playwright_ex` for direct browser control
- Uses Erlang Ports to communicate with Node.js
- Best for headless automation and local development

#### Remote Transport (`Playwriter.Transport.Remote`)

- Connects via WebSocket to a Playwright server
- Enables WSL-to-Windows browser visibility
- Supports distributed browser automation

Both transports implement `Playwriter.Transport.Behaviour`:

```elixir
@callback start_link(keyword()) :: {:ok, pid()} | {:error, term()}
@callback launch_browser(transport(), browser_type(), keyword()) :: {:ok, guid()}
@callback new_context(transport(), guid(), keyword()) :: {:ok, guid()}
@callback new_page(transport(), guid()) :: {:ok, map()}
@callback goto(transport(), guid(), String.t(), keyword()) :: {:ok, map()}
@callback content(transport(), guid()) :: {:ok, String.t()}
# ... and more
```

### 4. Server Discovery (`Playwriter.Server.Discovery`)

Automatically finds Playwright servers in WSL environments:

- Scans common ports (3337, 3336, 3335, etc.)
- Tries multiple host addresses (localhost, WSL gateway IP, etc.)
- Returns the first working endpoint

## Data Flow

### Local Mode

```
with_browser([])
     │
     ▼
Session.start_link()
     │
     ├──▶ Transport.Local.start_link()
     │         │
     │         └──▶ PlaywrightEx.Supervisor.start_link()
     │                    │
     │                    └──▶ Node.js Playwright Driver
     │
     ├──▶ launch_browser(:chromium)
     │         │
     │         └──▶ PlaywrightEx.launch_browser()
     │
     └──▶ new_page()
              │
              └──▶ Browser visible (if headless: false)
```

### Remote Mode (WSL to Windows)

```
with_browser([mode: :remote])
     │
     ▼
Session.start_link()
     │
     ├──▶ Discovery.discover()
     │         │
     │         └──▶ Find ws://localhost:3337/
     │
     ├──▶ Transport.Remote.start_link()
     │         │
     │         └──▶ WebSocket connect to Windows
     │
     └──▶ new_page()
              │
              └──▶ Browser visible on Windows desktop!
```

## Error Handling

Playwriter uses OTP patterns for robust error handling:

1. **Session supervision** - Sessions are independent GenServers
2. **Transport isolation** - Transport failures don't crash sessions
3. **Resource cleanup** - `terminate/2` ensures browsers are closed
4. **Graceful degradation** - Remote failures fall back cleanly

## Extension Points

### Custom Transports

Implement `Playwriter.Transport.Behaviour` for custom scenarios:

```elixir
defmodule MyApp.CustomTransport do
  @behaviour Playwriter.Transport.Behaviour

  @impl true
  def start_link(opts) do
    # Your implementation
  end

  # ... implement other callbacks
end
```

### Session Callbacks

The Session GenServer can be extended:

```elixir
# Get session state for debugging
:sys.get_state(session_pid)
```

## Performance Considerations

1. **Reuse sessions** - Creating browsers is expensive
2. **Use headless mode** - Faster than headed browsers
3. **Local transport** - Lower latency than remote
4. **Connection pooling** - Consider for high-throughput scenarios
