# Windows Browser Integration for WSL

This guide explains how to use Windows browsers (Chrome/Firefox) from your Elixir Playwright app running in WSL.

## Overview

Since WSL runs in a Linux environment, it cannot directly launch Windows GUI applications. However, Playwright supports remote browser connections via WebSocket, which allows us to:

1. Run a Playwright server on Windows
2. Connect to it from WSL
3. Control Windows browsers from your Elixir app

## Setup Methods

### Method 1: Automated Setup (Recommended)

Run the setup script:

```bash
./setup_windows_browser.sh
```

This will:
- Start a Playwright server on Windows (port 3333)
- Display the WebSocket endpoint
- Keep the server running in a PowerShell window

### Method 2: Manual Setup

1. **On Windows (PowerShell):**
   ```powershell
   # Navigate to a temporary directory
   cd $env:TEMP
   
   # Install Playwright
   npm init -y
   npm install playwright
   
   # Install browsers
   npx playwright install chromium
   npx playwright install firefox
   
   # Start the server
   npx playwright run-server --port 3333
   ```

2. **Find your Windows host IP from WSL:**
   ```bash
   cat /etc/resolv.conf | grep nameserver
   ```

3. **Connect from your Elixir app:**
   ```elixir
   # Direct connection
   {:ok, browser} = Playwright.connect(:chromium, %{
     ws_endpoint: "ws://172.24.144.1:3333/"  # Use your Windows IP
   })
   ```

## Usage

### Command Line

```bash
# Use Windows Chrome
./playwriter --windows-browser https://example.com

# Use Windows Firefox
./playwriter --windows-firefox https://example.com
```

### In Your Code

```elixir
# Option 1: Use the fetch helper with Windows browser
{:ok, html} = Playwriter.Fetcher.fetch_html("https://example.com", %{
  use_windows_browser: true,
  browser_type: :chromium  # or :firefox
})

# Option 2: Use the adapter directly
{:ok, browser} = Playwriter.WindowsBrowserAdapter.connect_windows_browser(:chromium)
{:ok, page} = Playwright.Browser.new_page(browser)
Playwright.Page.goto(page, "https://example.com")
```

## Troubleshooting

### PowerShell window closes immediately
This usually means Node.js or npm is not installed on Windows:
1. Install Node.js on Windows from https://nodejs.org/
2. Restart your terminal/PowerShell
3. Run `./setup_windows_browser.sh` again

### "Connection refused" error
1. Check if the server is running:
   ```bash
   mix run test_windows_connection.exs
   ```

2. Manually start the server on Windows:
   - Open Windows Explorer
   - Navigate to this project directory
   - Double-click `start_windows_server.bat`

3. Check Windows Firewall:
   - Windows may prompt to allow Node.js through the firewall
   - Accept the prompt when it appears

### "Browser not found" error
The server will automatically install browsers, but if it fails:
1. Open PowerShell on Windows as Administrator
2. Run:
   ```powershell
   cd $env:TEMP\playwright-wsl-server
   npx playwright install chromium
   npx playwright install firefox
   ```

### Finding the correct Windows IP
```bash
# The setup script finds it automatically, but to check manually:
cat /etc/resolv.conf | grep nameserver | awk '{print $2}'
```

### Testing the connection
```bash
# Quick test script
mix run test_windows_connection.exs

# Or use the CLI
./playwriter --windows-browser https://example.com
```

### Common Issues

1. **WSL2 vs WSL1**: This solution works best with WSL2. Check your version:
   ```bash
   wsl --status
   ```

2. **VPN/Corporate Network**: Some VPNs may interfere with WSL networking

3. **Multiple WSL Distros**: The IP address may vary between distros

## Benefits

- **Real browser testing**: Test with actual Windows Chrome/Firefox installations
- **Debugging**: See the browser window and interact with it
- **Cross-platform testing**: Test how your scraper works on Windows browsers
- **Session persistence**: Keep browser sessions alive between requests

## Security Notes

- The Playwright server accepts connections from any IP by default
- For production use, consider:
  - Binding to specific IPs
  - Using authentication tokens
  - Running behind a reverse proxy

## Alternative: X Server Approach

If you prefer to run Linux browsers with GUI in WSL:
1. Install an X Server on Windows (e.g., VcXsrv, X410)
2. Set DISPLAY environment variable in WSL
3. Run Playwright with `headless: false`

However, the WebSocket approach is generally more reliable and doesn't require X Server configuration.