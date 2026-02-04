# Playwriter Examples

Runnable examples demonstrating Playwriter's browser automation capabilities.

## Prerequisites

Before running examples, you need either:

**Option A: Local Mode**
```bash
mix playwriter.setup
```

**Option B: Remote Mode (WSL to Windows)**
```bash
# From WSL (bypass execution policy)
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1
```

Or manually on Windows PowerShell:
```powershell
cd $env:TEMP; mkdir playwriter-server -ErrorAction SilentlyContinue; cd playwriter-server
npm init -y; npm install playwright; npx playwright install chromium
node -e "const{chromium}=require('playwright');chromium.launchServer({headless:false,port:3337}).then(s=>console.log(s.wsEndpoint()))"
```

## Running Examples

All examples support both local and remote modes:

```bash
# Auto-detect available mode
mix run examples/fetch_html.exs

# Force local mode (headless browser on this machine)
mix run examples/fetch_html.exs --local

# Force remote mode (visible browser on Windows)
mix run examples/fetch_html.exs --remote

# Remote with explicit endpoint
mix run examples/fetch_html.exs --remote --endpoint ws://localhost:3337/
```

## Available Examples

### fetch_html.exs

Fetches HTML content from a webpage.

```bash
mix run examples/fetch_html.exs
```

**What it does:**
1. Opens a browser (headless or visible depending on mode)
2. Navigates to example.com
3. Extracts the HTML content
4. Prints the first 500 characters

**Code highlights:**
```elixir
{:ok, html} = Playwriter.fetch_html("https://example.com")
```

---

### screenshot.exs

Takes a screenshot of a webpage.

```bash
mix run examples/screenshot.exs
```

**What it does:**
1. Opens a browser
2. Navigates to example.com
3. Captures a PNG screenshot
4. Saves to `screenshot.png`

**Output:** `screenshot.png` in current directory

**Code highlights:**
```elixir
{:ok, png_data} = Playwriter.screenshot("https://example.com")
File.write!("screenshot.png", png_data)
```

---

### interaction.exs

Demonstrates form filling and button clicking.

```bash
mix run examples/interaction.exs
```

**What it does:**
1. Opens a browser
2. Navigates to httpbin.org/forms/post
3. Fills in form fields (name, email, phone)
4. Clicks the submit button
5. Shows the result page

**Code highlights:**
```elixir
Playwriter.with_browser(opts, fn ctx ->
  :ok = Playwriter.goto(ctx, "https://httpbin.org/forms/post")
  :ok = Playwriter.fill(ctx, "input[name=custname]", "Test User")
  :ok = Playwriter.fill(ctx, "input[name=custemail]", "test@example.com")
  :ok = Playwriter.click(ctx, "button")
  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

---

### windows_browser.exs

Specifically demonstrates WSL-to-Windows browser control.

```bash
# Requires Windows server running
mix run examples/windows_browser.exs
```

**What it does:**
1. Discovers the Windows Playwright server
2. Opens a **visible** browser on your Windows desktop
3. Navigates to example.com (you can watch it!)
4. Waits 2 seconds so you can see the browser
5. Takes a screenshot
6. Closes the browser

**Output:** `windows_screenshot.png`

**This example is remote-only** - it's specifically for demonstrating the WSL-to-Windows feature.

---

## CLI Options

All examples support these flags:

| Flag | Short | Description |
|------|-------|-------------|
| `--local` | `-l` | Force local mode (headless) |
| `--remote` | `-r` | Force remote mode (Windows) |
| `--endpoint URL` | `-e` | Specify WebSocket endpoint |
| `--headless` | `-h` | Run headless (even in remote mode) |

## Mode Auto-Detection

When you don't specify `--local` or `--remote`, examples auto-detect:

1. **Try remote first** - Check if a Windows server is running
2. **Fall back to local** - If no server, try local Playwright
3. **Show error** - If neither works, show setup instructions

This means in WSL with a Windows server running, examples automatically use remote mode and show you the browser.

## Error Messages

Examples provide helpful error messages:

**No local Playwright:**
```
============================================================
ERROR: Local Playwright not installed
============================================================

To use local mode, run:

    mix playwriter.setup
```

**No Windows server:**
```
============================================================
ERROR: No Playwright server found
============================================================

To use remote mode, start the Windows server:

    powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1
```

## Writing Your Own Scripts

Use the examples as templates:

```elixir
# my_script.exs

# Simple one-liner
{:ok, html} = Playwriter.fetch_html("https://mysite.com")

# With options
{:ok, html} = Playwriter.fetch_html("https://mysite.com",
  mode: :remote,        # or :local
  headless: false,      # show browser
  timeout: 60_000       # 60 second timeout
)

# Complex interaction
{:ok, result} = Playwriter.with_browser([mode: :remote], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://mysite.com/login")
  :ok = Playwriter.fill(ctx, "#email", "me@example.com")
  :ok = Playwriter.fill(ctx, "#password", "secret")
  :ok = Playwriter.click(ctx, "button[type=submit]")

  # Wait for navigation
  Process.sleep(2000)

  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

Run your script:
```bash
mix run my_script.exs
```

## Troubleshooting

### Examples fail immediately

Check that you have either local Playwright or Windows server:

```bash
# Check local
ls deps/playwright/priv/static/node_modules/playwright/cli.js

# Check remote (should show endpoint)
mix run -e "IO.inspect Playwriter.Server.Discovery.discover()"
```

### Browser doesn't appear in remote mode

Make sure you're not passing `--headless`:
```bash
mix run examples/windows_browser.exs  # Not --headless
```

### Timeout errors

Increase the timeout or check network connectivity:
```elixir
Playwriter.fetch_html(url, timeout: 120_000)
```

### "Target closed" errors

The browser closed unexpectedly. Don't manually close browser windows during automation.
