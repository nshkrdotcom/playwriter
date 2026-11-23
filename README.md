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

## Browser automation from WSL

Playwriter supports headless and visible browsers. In local mode, the browser
runs alongside Elixir and can display a window through WSLg. In Windows mode,
Elixir runs in WSL and controls a native Windows browser through a Node worker
started by PowerShell. The worker uses stdin and stdout, so setup requires no
WebSocket server or firewall configuration.

## Quick Start

### Installation

Add to your `mix.exs`:

```elixir
def deps do
  [{:playwriter, "~> 0.4.0"}]
end
```

Playwriter requires Elixir 1.18 or newer. Install a supported Node LTS (minimum Node 20) in the environment that runs the selected browser driver.

| Mode | Driver environment | Setup from your Mix project |
| --- | --- | --- |
| Local headless | Your Mix shell | `mix playwriter.setup` |
| Visible Chrome for Testing via WSLg | WSL | `mix playwriter.setup`, then run with `headless: false` |
| Native Windows from WSL | Windows PowerShell | `mix playwriter.setup --mode windows --browser chrome` |

Run `mix deps.get` first. Setup verifies browser launch, navigation and shutdown. Add `--check` to inspect prerequisites and installed files without launching a browser. See [Getting Started](guides/getting-started.md) for setup paths and CLI overrides.

### Basic Usage (Local/Headless)

```elixir
# Fetch HTML from a page
{:ok, html} = Playwriter.fetch_html("https://example.com")

# Take a screenshot
{:ok, png} = Playwriter.screenshot("https://example.com")
File.write!("screenshot.png", png)
```

### WSL to Windows (Visible Browser)

From WSL, after installing Windows Node and npm through your workstation setup:

```bash
export PLAYWRITER_WINDOWS_CHANNEL=chrome # or msedge for installed Edge
mix playwriter.setup --mode windows
mix playwriter.setup --mode windows --check
```

See [WSL–Windows Setup](guides/wsl-windows.md) for the Windows and WSL checks.

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

## Browser Automation Capabilities

Beyond navigation and form interaction, Playwriter exposes the surface a
dev/test harness needs. Each is a `Playwriter.Browser.Session` function (and,
for the page-scoped ones, a `with_browser/2` facade wrapper):

```elixir
{:ok, session} = Playwriter.Browser.Session.start_link(mode: :windows)
alias Playwriter.Browser.Session

# Evaluate arbitrary JavaScript and get the serialized result
{:ok, ctx} = Session.new_context(session, [])

# Install a context-scoped init script BEFORE the page loads
:ok = Session.add_init_script(session, ctx, "window.__debug = 1")

{:ok, page} = Session.new_page(session, context_guid: ctx)
:ok = Session.goto(session, page, "http://localhost:4000")

{:ok, true}  = Session.evaluate(session, page, "crossOriginIsolated")
{:ok, title} = Session.evaluate(session, page, "document.title")

# Wait for a predicate to become truthy (polling / timeout)
:ok = Session.wait_for_function(session, page, "window.__ready === true", timeout: 60_000)
```

Inside `with_browser/2` the page-scoped verbs have thin wrappers:

```elixir
Playwriter.with_browser([mode: :windows], fn ctx ->
  :ok = Playwriter.goto(ctx, "http://localhost:4000")
  :ok = Playwriter.wait_for_function(ctx, "document.readyState === 'complete'")
  {:ok, value} = Playwriter.evaluate(ctx, "window.__souleqDebug.snapshot()")
  value
end)
```

### Start past an auth gate — `add_cookies` / `storage_state`

```elixir
{:ok, ctx} = Session.new_context(session, [])
:ok = Session.add_cookies(session, ctx, [
  %{name: "_session", value: signed, domain: "localhost", path: "/", sameSite: "Lax"}
])
{:ok, page} = Session.new_page(session, context_guid: ctx)   # already authenticated
{:ok, state} = Session.storage_state(session, ctx)           # capture cookies + localStorage
```

### CDP (network fault injection) — `:windows` only

```elixir
{:ok, cdp} = Session.new_cdp_session(session, page)
{:ok, _}   = Session.cdp_send(session, cdp, "Network.emulateNetworkConditions", %{
  offline: false, latency: 200, downloadThroughput: 100_000, uploadThroughput: 100_000
})
{:ok, _}   = Session.cdp_send(session, cdp, "Network.setBlockedURLs", %{urls: ["*://ads.example/*"]})
```

The `:local` transport has no CDP (`playwright_ex` exposes none) and returns
`{:error, :not_supported}`; use server-side fault injection there.

### Page → Elixir callbacks (experimental, `:windows` only)

```elixir
:ok = Session.expose_binding(session, ctx, "report", fn [payload] ->
  send(self(), {:from_page, payload}); :ack
end)
# page can now call window.report(data)
```

Binary returns (e.g. `screenshot/3`) use an explicit base64 contract and come
back as decoded binaries. See the **Automation Capabilities** guide for details.

## Browser Modes

| Mode | Use Case | Browser Location |
|------|----------|------------------|
| `:local` (default) | CI/CD, headless scraping | Same machine as Elixir |
| `:windows` | WSL development, debugging, demos | Windows desktop (visible) |


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
  mode: :windows,                   # :local or :windows
  headless: false,                  # true for invisible, false to watch
  browser_type: :chromium,          # Firefox and WebKit are available in local mode
  timeout: 30_000                   # navigation timeout in milliseconds
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
- **[Transport Layer](guides/transports.md)** - Local and Windows transports
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
