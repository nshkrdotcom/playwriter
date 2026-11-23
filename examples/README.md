# Playwriter Examples

Runnable examples demonstrating Playwriter's browser automation capabilities.

## Prerequisites

Before running examples, you need either:

**Option A: Local Mode**
```bash
mix playwriter.setup
```

**Option B: Windows Mode (from WSL)**
```bash
# From WSL after installing Windows Node/npm
mix playwriter.setup --mode windows
```


## Running Examples

The general-purpose examples support local and Windows modes:

```bash
# Auto-detect available mode
mix run examples/fetch_html.exs

# Force local mode (headless browser on this machine)
mix run examples/fetch_html.exs --local

# Force Windows mode (visible browser on Windows)
mix run examples/fetch_html.exs --windows

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

**This example uses Windows mode** - it's specifically for demonstrating the WSL-to-Windows feature.

---

## CLI Options

All examples support these flags:

| Flag | Short | Description |
|------|-------|-------------|
| `--local` | `-l` | Force local mode (headless) |
| `--windows` | `-w` | Force visible Windows mode |
| `--headless` | `-h` | Run headless (in either mode) |

## Mode Auto-Detection

When you don't specify `--local` or `--windows`, examples auto-detect:

1. **Try Windows first** - Check the Windows stdio driver
2. **Fall back to local** - Check the local driver if Windows is unavailable
3. **Show error** - If neither works, show setup instructions

From WSL with Windows setup complete, the default opens a visible browser on Windows.

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

============================================================



    mix playwriter.setup --mode windows
```

## Writing Your Own Scripts

Use the examples as templates:

```elixir
# my_script.exs

# Simple one-liner
{:ok, html} = Playwriter.fetch_html("https://mysite.com")

# With options
{:ok, html} = Playwriter.fetch_html("https://mysite.com",
  mode: :windows,        # or :local
  headless: false,      # show browser
  timeout: 60_000       # 60 second timeout
)

# Complex interaction
{:ok, result} = Playwriter.with_browser([mode: :windows], fn ctx ->
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

Check that you have the required driver for your mode:

```bash
# Check local
mix playwriter.setup --check

# Check Windows from WSL
mix playwriter.setup --mode windows --check
```

### Browser doesn't appear in Windows mode

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
