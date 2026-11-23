# Getting Started

Playwriter 0.4 requires Elixir 1.18 or newer and Node.js 20 or newer for the driver. Use a supported Node LTS. Install Node through the package manager or workstation bootstrap that owns the target host.

| Mode | Elixir runs in | Node and Chromium run in | Setup command |
| --- | --- | --- | --- |
| `:local` (default) | Your current shell | The same environment, headless by default | `mix playwriter.setup` |
| `:local` with `headless: false` | WSL | WSL, displayed through WSLg | `mix playwriter.setup` |
| `:windows` | WSL | Windows, visible by default | `mix playwriter.setup --mode windows --browser chrome` |

Add Playwriter to the dependencies in your application's `mix.exs`:

```elixir
{:playwriter, "~> 0.4.0"}
```

Run `mix deps.get` from the application before setting up a driver.

## Local headless browser

Verify `node --version` and `npm --version` in the shell that runs Mix. If your runtime manager initializes only in your login shell, use that shell or configure CI to load the manager explicitly.

```bash
mix playwriter.setup
mix playwriter.setup --check
mix run -e 'IO.inspect(Playwriter.fetch_html("data:text/html,<h1>Playwriter</h1>"))'
```

Setup installs the locked npm driver into `.playwriter-driver/` and downloads its matching Chromium into Playwright's browser cache. You can select Firefox, WebKit or all browsers with `--browser`. On Linux, `--with-deps` explicitly requests system libraries and may require elevated privileges. `PLAYWRIGHT_BROWSERS_PATH` can select a dedicated cache. Use the same value for setup, checks and runs.

The local transport honors `PLAYWRIGHT_CLI` and then `config :playwriter, :playwright_cli` when you supply a driver yourself. Use the npm driver version tested with this release.

## Visible Chrome for Testing in WSL

After local setup, run with `mode: :local, headless: false` in a WSL shell with WSLg available:

```bash
mix run -e 'IO.inspect(Playwriter.fetch_html("data:text/html,<h1>Playwriter</h1>", mode: :local, headless: false))'
```

The browser runs in Linux and the window appears on the Windows desktop.

## Native Windows browser from WSL

Install Node and npm on the **Windows** host first. Then use the commands in [WSL–Windows Setup](wsl-windows.md) to verify interop and prepare Windows Chromium. Run Playwriter from WSL with `mode: :windows`.

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
  mode: :windows,         # :local or :windows
  headless: false,        # show browser window (local mode only)
  browser_type: :chromium,# :chromium, :firefox, :webkit (local mode)
  timeout: 60_000         # milliseconds
)
```

See [Function Reference](functions.md), [Usage Examples](examples.md) and [Troubleshooting](troubleshooting.md).
