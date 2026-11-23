# WSL–Windows Setup

Use `mode: :windows` to run a visible Chrome, Edge, or managed Chrome for Testing browser on your Windows desktop with Elixir in WSL. Playwriter launches a Windows Node worker via PowerShell and communicates over stdio. The supported path requires WSL interop and a Windows desktop session for visible operation.

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

## 2. Choose and verify a Windows browser

From **WSL**, at your Mix project, select a browser that is already installed on Windows:

```bash
mix deps.get
export PLAYWRITER_WINDOWS_CHANNEL=chrome  # or msedge
mix playwriter.setup --mode windows
mix playwriter.setup --mode windows --check
```

You can select `--browser chrome`, `--browser msedge`, or `--browser chromium` for a single setup command. The flag takes precedence over `PLAYWRITER_WINDOWS_CHANNEL`, which takes precedence over `config :playwriter, :windows_channel, "chrome"`. For subsequent runs, set the environment variable or application config to the same browser. With no selection, Windows setup prints the choices. Existing Windows runtime calls with no selection continue to use managed Chromium.

Installed Chrome and Edge use the pinned driver staged under `playwriter-stdio-*` in the active Windows account's temp folder. This setup does not download a browser. Use `--browser chromium` or set the channel to `chromium` to opt into Playwright-managed **Chrome for Testing** in the Windows Playwright cache. Windows Code Integrity can block that unsigned build. To run Chrome for Testing visibly in WSL, see [Getting Started](getting-started.md#visible-chrome-for-testing-in-wsl).

Setup reports ready after the chosen browser opens, loads a local test page, and closes. `--check` checks prerequisites and files without launching the browser. Re-run setup if Windows temp is cleared or Playwriter reports a stale worker.

If you configure `config :playwriter, :windows_user, "YourWindowsUser"`, the value must match the active Windows PowerShell account. Run WSL under the intended Windows account to change which desktop and cache the worker uses.

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
  {:ok, before} = Playwriter.take_screenshot(ctx)
  File.write!("before.png", before)

  :ok = Playwriter.click(ctx, "button.submit")
  Process.sleep(1000)  # Wait for navigation

  # Screenshot after
  {:ok, after_shot} = Playwriter.take_screenshot(ctx)
  File.write!("after.png", after_shot)
end)
```

For setup failures see [Troubleshooting](troubleshooting.md). The legacy WebSocket transport `:remote` is unsupported.
