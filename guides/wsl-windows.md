# WSL–Windows Setup

Use `mode: :windows` to run a visible Chromium on your Windows desktop with Elixir in WSL. Playwriter launches a Windows Node worker via PowerShell and communicates over stdio. The supported path requires WSL interop and a Windows desktop session for visible operation.

## 1. Verify Windows Node

Use your Windows workstation bootstrap to provision a supported Node LTS. In **Windows PowerShell**, run:

```powershell
Get-Command node.exe, npm.cmd
node.exe --version
npm.cmd --version
```

The driver needs Node 20 or newer. Verify the same account that WSL uses. To check interop from **WSL**:

```bash
powershell.exe -NoProfile -NonInteractive -Command 'whoami; $env:TEMP'
```

Playwriter selects PowerShell 7 at its standard installation path when available and can use inbox Windows PowerShell. Open a fresh shell after changing Windows PATH. A WSL Node already installed by asdf only serves the local transport.

## 2. Provision the Windows driver and Chromium

From **WSL**, at your Mix project:

```bash
mix deps.get
mix playwriter.setup --mode windows
mix playwriter.setup --mode windows --check
```

Setup checks the target account and Windows Node/npm before writing files. It installs the locked driver and stages the stdio worker under a versioned `playwriter-stdio-*` directory in the active Windows account's temp folder. The matching browser goes in Playwright's Windows browser cache. Expect `Playwriter windows driver and chromium ready.` The check uses the staged driver and does not download files. Re-run setup if Windows temp gets cleared or Playwriter reports that the worker is stale.

If you configure `config :playwriter, :windows_user, "YourWindowsUser"`, the value must match the active Windows PowerShell account. Run WSL under the intended Windows account to change which desktop and cache the worker uses.

### Use an installed Windows browser

Managed Chromium is the default. If Windows policy blocks that build, select a browser your host already allows using Playwright's `msedge` or `chrome` channel. In WSL, for example:

```bash
export PLAYWRITER_WINDOWS_CHANNEL=msedge
mix playwriter.setup --mode windows
mix playwriter.setup --mode windows --check
```

Keep the same setting for browser runs. You can also configure `config :playwriter, :windows_channel, "msedge"`. Channel setup uses the installed browser and skips the managed browser download. The read-only check verifies installed files. Use the smoke test below to verify Windows allows the browser to launch and be automated.

## 3. Open a visible browser

From **WSL**, run:

```bash
mix run -e 'IO.inspect(Playwriter.fetch_html("data:text/html,<h1>Playwriter</h1>", mode: :windows))'
```

The command prints the HTML and closes the browser when it finishes. For an interactive example, use `mix run examples/windows_browser.exs` from a source checkout.

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

For setup failures see [Troubleshooting](troubleshooting.md). The legacy WebSocket transport `:remote` is unsupported.
