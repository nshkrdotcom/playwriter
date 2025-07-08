# Playwriter - Cross-Platform Browser Automation for Elixir

[![Hex.pm](https://img.shields.io/hexpm/v/playwriter.svg)](https://hex.pm/packages/playwriter)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/playwriter)
[![License](https://img.shields.io/hexpm/l/playwriter.svg)](https://github.com/nshkrdotcom/playwriter/blob/main/LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-nshkrdotcom%2Fplaywriter-blue.svg)](https://github.com/nshkrdotcom/playwriter)

**Playwriter** is an Elixir library that provides **full Playwright browser automation capabilities** with advanced WSL-to-Windows integration. It exposes the complete Playwright API through a composable design while handling complex browser setup, Windows browser control, and Chrome profile management automatically.

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Usage Examples](#usage-examples)
- [Windows Browser Integration](#windows-browser-integration)
- [Architecture Overview](#architecture-overview)
- [Installation & Setup](#installation--setup)
- [Core Modules](#core-modules)
- [Scripts & Utilities](#scripts--utilities)
- [Development & Debugging](#development--debugging)
- [Troubleshooting](#troubleshooting)
- [Architecture Diagrams](./diagrams.md)

## Features

- **🎯 Full Playwright API Access**: Complete browser automation capabilities through composable design
- **🔧 Composable Architecture**: Use any Playwright function with automatic browser setup
- **🖥️ Windows Browser Integration**: Control visible Windows browsers from WSL with WebSocket
- **👤 Chrome Profile Support**: Access existing Chrome profiles and user data
- **🎨 Headed/Headless Modes**: Visible browser windows for debugging or headless for automation
- **📱 Cross-Platform**: Works on Linux, macOS, and Windows with WSL integration
- **🔄 Automatic Cleanup**: Proper resource management and process cleanup
- **📡 Network Discovery**: Robust server discovery across multiple ports and interfaces

## Quick Start

```elixir
# Add to your mix.exs
def deps do
  [
    {:playwriter, "~> 0.0.2"}
  ]
end

# Basic usage - any Playwright operation
{:ok, html} = Playwriter.with_browser(%{}, fn page ->
  Playwright.Page.goto(page, "https://example.com")
  Playwright.Page.content(page)
end)

# Take screenshots
{:ok, _} = Playwriter.screenshot("https://example.com", "screenshot.png")

# Complex automation
{:ok, title} = Playwriter.with_browser(%{}, fn page ->
  Playwright.Page.goto(page, "https://example.com")
  Playwright.Page.click(page, "#login")
  Playwright.Page.fill(page, "#username", "user")
  Playwright.Page.screenshot(page, %{path: "after_login.png"})
  Playwright.Page.title(page)
end)
```

## API Reference

### Core Functions

#### `Playwriter.with_browser/2`
**The main composable function that provides full Playwright API access.**

```elixir
Playwriter.with_browser(opts, fun)
```

**Options:**
- `:use_windows_browser` - Use Windows browser via WebSocket (default: false)
- `:browser_type` - Browser type (`:chromium`, `:firefox`, `:webkit`)
- `:headless` - Run in headless mode (default: true)
- `:chrome_profile` - Chrome profile name for Windows browsers
- `:cookies` - List of cookies to set
- `:headers` - Headers to set
- `:ws_endpoint` - Explicit WebSocket endpoint for remote browsers

**Returns:** `{:ok, result}` or `{:error, reason}`

#### `Playwriter.screenshot/3`
**Convenience function for taking screenshots.**

```elixir
Playwriter.screenshot(url, path, opts \\ %{})
```

#### `Playwriter.fetch_html/2`
**Convenience function for HTML fetching (backward compatibility).**

```elixir
Playwriter.fetch_html(url, opts \\ %{})
```

### Available Playwright Operations

With `Playwriter.with_browser/2`, you can use **any** Playwright function:

```elixir
# Navigation
Playwright.Page.goto(page, url)
Playwright.Page.go_back(page)
Playwright.Page.go_forward(page)
Playwright.Page.reload(page)

# Content & Screenshots
Playwright.Page.content(page)
Playwright.Page.screenshot(page, options)
Playwright.Page.pdf(page, options)

# Element Interaction
Playwright.Page.click(page, selector)
Playwright.Page.fill(page, selector, value)
Playwright.Page.select_option(page, selector, value)
Playwright.Page.check(page, selector)
Playwright.Page.uncheck(page, selector)

# Waiting
Playwright.Page.wait_for_selector(page, selector)
Playwright.Page.wait_for_load_state(page, state)
Playwright.Page.wait_for_timeout(page, timeout)

# Evaluation
Playwright.Page.evaluate(page, script)
Playwright.Page.evaluate_handle(page, script)

# Information
Playwright.Page.title(page)
Playwright.Page.url(page)
Playwright.Page.text_content(page, selector)
Playwright.Page.inner_text(page, selector)
Playwright.Page.inner_html(page, selector)
```

## Architecture Overview

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Elixir CLI    │────│   Fetcher       │────│ Local Playwright│
│   (playwriter)  │    │   (fetcher.ex)  │    │   (headless)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         │              ┌─────────────────┐    ┌─────────────────┐
         └──────────────│Windows Adapter  │────│Windows Playwright│
                        │(adapter.ex)     │    │   (headed)      │
                        └─────────────────┘    └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │   WebSocket     │
                        │  (WSL ↔ Win)    │
                        └─────────────────┘
```

### Windows Integration Architecture

The Windows browser integration uses a client-server architecture:

1. **Playwright Server** runs on Windows (Node.js) with `launchServer({headless: false})`
2. **WebSocket Bridge** connects WSL to Windows across network boundary
3. **Elixir Client** controls remote browsers via WebSocket endpoint
4. **Browser Context** manages profiles, sessions, and page lifecycle

### Key Innovation: Cross-Platform Browser Control

This system solves the unique challenge of WSL-to-Windows browser automation:

- **Network Bridge**: Automatic discovery of WSL gateway IPs and port scanning
- **Headed Server**: True visible browser windows (not just headless automation)
- **Profile Integration**: Access to Windows Chrome profiles and user data
- **Process Management**: Clean startup, shutdown, and cleanup of background processes

## Installation & Setup

### Prerequisites

- **Elixir 1.18+** with Mix
- **WSL2** (for Windows integration)
- **Node.js** installed on Windows (for Playwright server)
- **Windows Chrome/Chromium** (for profile support)

### Installation from Hex

Add `playwriter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:playwriter, "~> 0.0.1"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

### Installation from Source

```bash
# Clone and build
git clone https://github.com/nshkrdotcom/playwriter.git
cd playwriter
mix deps.get
mix escript.build

# Test local functionality
./playwriter test
```

### Windows Integration Setup

```bash
# 1. Kill any existing Playwright processes
powershell.exe -ExecutionPolicy Bypass -File ./kill_playwright.ps1

# 2. Start the headed browser server
./start_true_headed_server.sh

# 3. Test Windows browser integration
./playwriter --windows-browser https://google.com
```

The server will output something like:
```
✅ HEADED Browser Server started successfully!
📡 WebSocket endpoint: ws://localhost:62426/e55d5f259c4e26a15376ae87fd791210
🌐 Browsers will be VISIBLE when used
```

## Core Modules

### 1. Playwriter.CLI (`lib/playwriter/cli.ex`)

**Purpose**: Command-line interface and argument parsing

**Key Features**:
- Multiple operation modes (local, Windows, GUI, auth)
- Chrome profile support (planned)
- Error handling and user guidance
- Pattern matching for complex command combinations

**Usage Patterns**:
```elixir
case args do
  ["--windows-browser"] -> test_windows_browser("https://google.com")
  ["--windows-browser", url] -> test_windows_browser(url)
  ["--list-profiles"] -> list_chrome_profiles()
  ["test", "--gui"] -> test_url_gui("https://google.com")
end
```

**Available Commands**:
```bash
./playwriter                           # Local headless browser
./playwriter https://example.com       # Custom URL
./playwriter test --gui               # Local headed browser
./playwriter test --auth              # Authentication demo
./playwriter --windows-browser        # Windows browser integration
./playwriter --list-profiles          # List Chrome profiles
```

### 2. Playwriter.Fetcher (`lib/playwriter/fetcher.ex`)

**Purpose**: Core HTML fetching logic with browser management

**Key Features**:
- Dual-mode operation (local vs. Windows browsers)
- Context management for different browser types
- Navigation options and error handling
- Profile-aware browser context creation

**Critical Code Paths**:
```elixir
# Windows browser detection and setup
{page, context, browser, should_close} = if opts[:use_windows_browser] do
  Logger.info("Using Windows browser via WebSocket connection")
  {:ok, browser} = WindowsBrowserAdapter.connect_windows_browser(browser_type, opts)
  
  # Profile-aware context creation
  if opts[:chrome_profile] do
    profile_path = "C:\\Users\\windo\\AppData\\Local\\Google\\Chrome\\User Data\\#{opts[:chrome_profile]}"
    context_options = %{viewport: %{width: 1920, height: 1080}}
    context = Playwright.Browser.new_context(browser, context_options)
    page = Playwright.BrowserContext.new_page(context)
    {page, context, browser, true}
  else
    page = Playwright.Browser.new_page(browser)
    {page, nil, browser, true}
  end
end
```

**Navigation Management**:
```elixir
navigation_options = %{
  timeout: 30_000,
  wait_until: "load"
}

case Playwright.Page.goto(page, url, navigation_options) do
  %Playwright.Response{} = response ->
    Logger.info("Navigation completed successfully (status: #{response.status})")
  {:error, error} ->
    Logger.error("Navigation failed: #{inspect(error)}")
    raise "Failed to navigate to #{url}: #{inspect(error)}"
end
```

### 3. Playwriter.WindowsBrowserAdapter (`lib/playwriter/windows_browser_adapter.ex`)

**Purpose**: WSL-to-Windows browser integration via WebSocket

**Key Features**:
- Multi-port server discovery with intelligent fallback
- Robust connection handling across network boundaries
- Chrome profile enumeration and management
- Network endpoint resolution for WSL environments

**Server Discovery Algorithm**:
```elixir
# Prioritized port discovery
ports_to_try = [3337, 3336, 3335, 3334, 3333, 9222, 9223]

# Multiple network endpoints for WSL environments
def get_possible_endpoints(port) do
  base_endpoints = [
    "ws://localhost:#{port}/",
    "ws://127.0.0.1:#{port}/",
    "ws://172.19.176.1:#{port}/",  # WSL gateway IP
    "ws://host.docker.internal:#{port}/"
  ]
  
  # Dynamic IP discovery
  additional_endpoints = case get_windows_host_ip() do
    {:ok, windows_host} -> ["ws://#{windows_host}:#{port}/"]
    _ -> []
  end
  
  additional_endpoints ++ base_endpoints
end
```

**Connection Management**:
```elixir
def connect_windows_browser(browser_type \\ :chromium, opts \\ %{}) do
  ws_endpoint = cond do
    opts[:ws_endpoint] -> opts[:ws_endpoint]
    System.get_env("PLAYWRIGHT_WS_ENDPOINT") -> System.get_env("PLAYWRIGHT_WS_ENDPOINT")
    true -> start_windows_playwright_server(%{browser: to_string(browser_type)})
  end
  
  {_session, browser} = Playwright.BrowserType.connect(ws_endpoint)
  {:ok, browser}
end
```

**Chrome Profile Discovery**:
```elixir
def get_chrome_profiles do
  chrome_path = "$env:LOCALAPPDATA + '\\Google\\Chrome\\User Data'"
  
  case System.cmd("powershell.exe", ["-Command", chrome_path]) do
    {path, 0} ->
      # Enumerate profile directories (Default, Profile 1, Profile 2, etc.)
      list_profile_directories(String.trim(path))
    _ ->
      {:error, "Could not find Chrome user data directory"}
  end
end
```

### 4. Playwriter.WindowsBrowserDirect (`lib/playwriter/windows_browser_direct.ex`)

**Purpose**: Alternative direct browser control methods (experimental)

Contains experimental approaches including:
- PowerShell automation
- WebView2 integration  
- Direct browser launching
- Simple HTTP requests via `Invoke-WebRequest`

**Note**: This module is preserved for alternative integration strategies but not used in the main workflow.

## Windows Browser Integration

### Server Architecture

The Windows integration uses Playwright's `launchServer` in headed mode:

```javascript
// Essential server configuration (in start_true_headed_server.sh)
const browserServer = await chromium.launchServer({
    headless: false  // Critical: enables visible browser windows
});

const wsEndpoint = browserServer.wsEndpoint();
// Returns: ws://localhost:PORT/GUID
console.log('WebSocket endpoint:', wsEndpoint);
```

### Network Bridge (WSL ↔ Windows)

**Challenge**: WSL and Windows have separate network stacks with different IP addresses
**Solution**: Multi-endpoint discovery with automatic fallback

```elixir
# Dynamic Windows host detection
def get_windows_host_ip do
  # Method 1: /etc/resolv.conf nameserver
  case System.cmd("cat", ["/etc/resolv.conf"]) do
    {output, 0} ->
      case Regex.run(~r/nameserver\s+(\d+\.\d+\.\d+\.\d+)/, output) do
        [_, ip] -> {:ok, ip}
        _ -> try_alternative_methods()
      end
  end
end

# Method 2: Default gateway detection  
case System.cmd("ip", ["route", "show", "default"]) do
  {output, 0} ->
    case Regex.run(~r/default via (\d+\.\d+\.\d+\.\d+)/, output) do
      [_, gateway_ip] -> {:ok, gateway_ip}
      _ -> {:error, "Could not find default gateway"}
    end
end
```

### Headed vs Headless: Critical Differences

**Previous Approach** (didn't work):
```bash
# playwright run-server (always headless)
npx playwright run-server --port 3336
```

**Current Solution** (works):
```javascript
// launchServer with headless: false
const browserServer = await chromium.launchServer({
    headless: false  // Enables visible browser windows
});
```

**Key Insight**: The `run-server` command only supports headless browsers. For visible browser windows, you must use `launchServer` programmatically.

### Profile Integration Challenges

**Current Limitation**: Chrome profiles must be set at browser launch, not context creation.

**Why This is Complex**:
```elixir
# This DOESN'T work - profiles need browser-level config
context_options = %{
  user_data_dir: "C:\\Users\\windo\\AppData\\Local\\Google\\Chrome\\User Data\\Profile 1"
}
context = Playwright.Browser.new_context(browser, context_options)
```

**Future Solution**: Profile-aware server launching
```javascript
// Planned enhancement
const browserServer = await chromium.launchServer({
    headless: false,
    args: ['--user-data-dir=C:\\Users\\windo\\AppData\\Local\\Google\\Chrome\\User Data\\Profile 1']
});
```

## Usage Examples

### 🎯 New Composable API (Recommended)

```elixir
# Full Playwright API access with automatic browser setup
{:ok, html} = Playwriter.with_browser(%{}, fn page ->
  Playwright.Page.goto(page, "https://example.com")
  Playwright.Page.content(page)
end)

# Take screenshots
{:ok, _} = Playwriter.with_browser(%{}, fn page ->
  Playwright.Page.goto(page, "https://example.com")
  Playwright.Page.screenshot(page, %{path: "screenshot.png"})
end)

# Complex automation workflows
{:ok, result} = Playwriter.with_browser(%{}, fn page ->
  Playwright.Page.goto(page, "https://example.com")
  Playwright.Page.click(page, "#login-button")
  Playwright.Page.fill(page, "#username", "user")
  Playwright.Page.fill(page, "#password", "pass")
  Playwright.Page.click(page, "#submit")
  Playwright.Page.wait_for_selector(page, ".dashboard")
  Playwright.Page.screenshot(page, %{path: "dashboard.png"})
  Playwright.Page.text_content(page, ".welcome-message")
end)

# Windows browser with profiles
{:ok, html} = Playwriter.with_browser(%{
  use_windows_browser: true,
  chrome_profile: "Profile 1",
  headless: false
}, fn page ->
  Playwright.Page.goto(page, "https://facebook.com")
  Playwright.Page.content(page)
end)
```

### 🚀 Convenience Functions

```elixir
# Quick HTML fetching
{:ok, html} = Playwriter.fetch_html("https://example.com")

# Quick screenshots
{:ok, _} = Playwriter.screenshot("https://example.com", "screenshot.png")

# With options
{:ok, html} = Playwriter.fetch_html("https://example.com", %{
  use_windows_browser: true,
  headless: false
})
```

### 🖥️ CLI Usage

```bash
# Local Playwright (headless)
./playwriter https://example.com

# Local Playwright (headed/GUI mode)  
./playwriter test --gui https://example.com

# With authentication headers
./playwriter test --auth https://httpbin.org/headers
```

### Windows Browser Integration

```bash
# Basic Windows browser usage
./playwriter --windows-browser https://google.com

# With specific browser type
./playwriter --windows-firefox https://mozilla.org

# Using environment variable for direct connection
PLAYWRIGHT_WS_ENDPOINT=ws://172.19.176.1:62426/abc123 ./playwriter --windows-browser https://google.com
```

### Profile Management

```bash
# List available Chrome profiles
powershell.exe -ExecutionPolicy Bypass -File ./list_chrome_profiles.ps1

# Start Playwright's Chromium for profile setup
powershell.exe -ExecutionPolicy Bypass -File ./start_chromium.ps1

# Future: Use specific profile (planned)
./playwriter --windows-browser --profile "Profile 1" https://facebook.com
```

### 🔧 Advanced Usage

```elixir
# Multiple operations in one browser session
{:ok, results} = Playwriter.with_browser(%{}, fn page ->
  pages_data = for url <- ["https://site1.com", "https://site2.com", "https://site3.com"] do
    Playwright.Page.goto(page, url)
    Playwright.Page.wait_for_load_state(page, "domcontentloaded")
    
    title = Playwright.Page.title(page)
    html = Playwright.Page.content(page)
    
    # Take screenshot for each page
    filename = url |> String.replace(~r/https?:\/\//, "") |> String.replace("/", "_")
    Playwright.Page.screenshot(page, %{path: "#{filename}.png"})
    
    %{url: url, title: title, html_length: String.length(html)}
  end
  
  pages_data
end)

# Using WindowsBrowserAdapter directly for advanced control
{:ok, browser} = Playwriter.WindowsBrowserAdapter.connect_windows_browser(:chromium)
page = Playwright.Browser.new_page(browser)
# ... direct Playwright operations
Playwright.Browser.close(browser)
```

## Scripts & Utilities

### Essential Scripts (Keep These)

#### `start_true_headed_server.sh` ⭐ **ESSENTIAL**
**Purpose**: Start headed Playwright server on Windows
**Usage**: `./start_true_headed_server.sh`

Creates Node.js script in Windows temp directory and launches `chromium.launchServer({headless: false})`.

```bash
# Key functionality
powershell.exe -Command "
  cd \$env:TEMP
  if (!(Test-Path 'node_modules/playwright')) {
    npm init -y
    npm install playwright
  }
  \$env:PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = '1'
  node headed_server.js
"
```

**Critical Output**: 
```
✅ HEADED Browser Server started successfully!
📡 WebSocket endpoint: ws://localhost:62426/e55d5f259c4e26a15376ae87fd791210
🌐 Browsers will be VISIBLE when used
```

#### `kill_playwright.ps1` ⭐ **ESSENTIAL**
**Purpose**: Clean termination of all Playwright processes
**Usage**: `powershell.exe -ExecutionPolicy Bypass -File ./kill_playwright.ps1`

```powershell
Get-Process node -ErrorAction SilentlyContinue | 
  Where-Object {$_.CommandLine -like '*playwright*'} | 
  Stop-Process -Force

Write-Host "Killed any orphaned Playwright processes"
```

**When to Use**: Before starting new servers, when processes get stuck, during development cleanup.

#### `list_chrome_profiles.ps1` ⭐ **ESSENTIAL**
**Purpose**: Enumerate available Chrome profiles
**Usage**: `powershell.exe -ExecutionPolicy Bypass -File ./list_chrome_profiles.ps1`

```powershell
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$profiles = Get-ChildItem $chromePath -Directory | 
  Where-Object {$_.Name -match '^(Default|Profile )' -or $_.Name -eq 'Profile 1'}

foreach ($profile in $profiles) {
    Write-Host "  - $($profile.Name) ($($profile.FullName))"
}
```

**Sample Output**:
```
Available Chrome profiles:
  - Default (C:\Users\windo\AppData\Local\Google\Chrome\User Data\Default)
  - Profile 1 (C:\Users\windo\AppData\Local\Google\Chrome\User Data\Profile 1)  
  - Profile 2 (C:\Users\windo\AppData\Local\Google\Chrome\User Data\Profile 2)
```

#### `start_chromium.ps1` ⭐ **ESSENTIAL**
**Purpose**: Launch Playwright's Chromium with custom profile for manual setup
**Usage**: `powershell.exe -ExecutionPolicy Bypass -File ./start_chromium.ps1`

```powershell
$chromiumPath = "$env:LOCALAPPDATA\ms-playwright\chromium-1179\chrome-win\chrome.exe"
$profilePath = "$env:TEMP\playwriter-chromium-profile"

if (Test-Path $chromiumPath) {
    & $chromiumPath --user-data-dir=$profilePath
} else {
    Write-Host "Chromium not found at $chromiumPath"
}
```

**Use Case**: Start Chromium manually to sign into accounts, set up bookmarks, configure settings that will be used during automation.

### Development Scripts (Optional)

#### Profile Management (Experimental)

#### `start_headed_with_profile.sh` 🧪 **EXPERIMENTAL**
**Purpose**: Start server with specific Chrome profile
**Status**: Under development - uses `launchPersistentContext` approach
**Usage**: `./start_headed_with_profile.sh "Default"`

**Current Limitation**: Creates persistent context but doesn't provide WebSocket endpoint for remote control.

### Deprecated Scripts (Remove These)

The following scripts were created during development but are superseded:

**Server Management (Superseded)**:
- `start_headed_server.sh` → Replaced by `start_true_headed_server.sh`
- `start_windows_playwright_server.sh` → Old `run-server` approach that only worked headless
- `start_headed_server_3334.ps1` → Port-specific version, now handles port discovery automatically

**Alternative/Experimental (Keep for Reference)**:
- `start_headed.ps1` → Individual PowerShell script, now embedded in bash script
- `custom_headed_server.js` → Standalone file approach, now dynamically generated

**Debug/Test Files (Clean Up)**:
- `debug_*.exs` - Various connection debugging scripts (remove after development)
- `simple_server_test.exs` - Basic functionality tests (archive)
- `check_*.exs` - Port and connection checking (archive)

**Manual Instructions (Archive)**:
- `manual_headed_instructions.md` - Manual setup instructions, superseded by automated scripts
- `playwright_server_manager.ps1` - Complex server management, replaced by simpler approach

## Development & Debugging

### Connection Flow Debugging

1. **Server Discovery**: Check `WindowsBrowserAdapter.get_possible_endpoints/1`
2. **Port Scanning**: Monitor `find_working_endpoint/1` logic 
3. **WebSocket Connection**: Verify `Playwright.BrowserType.connect/1` calls
4. **Browser Lifecycle**: Track page creation, navigation, and cleanup

### Debug Environment Variables

```bash
# Force specific endpoint (skip discovery)
PLAYWRIGHT_WS_ENDPOINT=ws://172.19.176.1:62426/abc123 ./playwriter --windows-browser https://google.com

# Enable verbose logging
export ELIXIR_LOG_LEVEL=debug
./playwriter --windows-browser https://google.com 2>&1 | grep -E "(info|error|debug)"
```

### Common Debug Points

Add to `fetcher.ex` for detailed debugging:
```elixir
Logger.info("=== BROWSER SETUP ===")
Logger.info("Options: #{inspect(opts)}")
Logger.info("Browser type: #{inspect(browser_type)}")
Logger.info("Use Windows browser: #{inspect(opts[:use_windows_browser])}")

Logger.info("=== NAVIGATION ===")
Logger.info("URL: #{url}")
Logger.info("Navigation options: #{inspect(navigation_options)}")

Logger.info("=== RESULTS ===")
Logger.info("HTML length: #{String.length(html)}")
Logger.info("Title: #{extract_title(html)}")
```

### Network Debugging

```bash
# Test WSL to Windows connectivity
powershell.exe -Command "Test-NetConnection -ComputerName 172.19.176.1 -Port 3337"

# Check what's listening on Windows
powershell.exe -Command "Get-NetTCPConnection -State Listen | Where-Object {$_.LocalPort -in @(3333,3334,3335,3336,3337)}"

# Verify WSL gateway IP
ip route show default
cat /etc/resolv.conf
```

### Server State Debugging

```bash
# Check if server is running
powershell.exe -Command "Get-Process node -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like '*playwright*'}"

# Test endpoint connectivity from WSL
curl -i --no-buffer -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: test" -H "Sec-WebSocket-Version: 13" ws://172.19.176.1:3337/
```

## Troubleshooting

### Windows Integration Issues

**Problem**: `No Playwright server found`
**Root Cause**: Server not running or network connectivity issue
**Solution**: 
```bash
# 1. Ensure server is running
./start_true_headed_server.sh
# Wait for: "✅ HEADED Browser Server started successfully!"

# 2. Test basic connectivity
./playwriter --windows-browser https://google.com

# 3. If still failing, force endpoint
PLAYWRIGHT_WS_ENDPOINT=ws://172.19.176.1:PORT/GUID ./playwriter --windows-browser https://google.com
```

**Problem**: `Target page, context or browser has been closed`
**Root Cause**: Manually closing browser windows during automation
**Solution**: Don't manually close browser windows - let automation complete and close automatically

**Problem**: Browser opens but shows blank page with Playwright inspector
**Root Cause**: Using `run-server` (headless only) or `PWDEBUG=1` environment variable
**Solution**: 
- Use `start_true_headed_server.sh` (uses `launchServer` not `run-server`)
- Ensure `PWDEBUG` environment variable is not set
- The browser should navigate automatically without requiring "Play" button

### Network/Connection Issues

**Problem**: `Connection refused` or `ECONNREFUSED` on WSL
**Root Cause**: Windows Firewall or incorrect IP address
**Solution**: 
```bash
# Check Windows Firewall
powershell.exe -Command "Get-NetFirewallRule -DisplayName '*Node*' -Enabled True"

# Test multiple IPs
for ip in localhost 127.0.0.1 172.19.176.1; do
  echo "Testing $ip:3337"
  timeout 2 bash -c "</dev/tcp/$ip/3337" && echo "Connected" || echo "Failed"
done
```

**Problem**: Multiple servers on different ports
**Root Cause**: Previous servers not properly cleaned up
**Solution**: 
```bash
powershell.exe -ExecutionPolicy Bypass -File ./kill_playwright.ps1
# Wait 5 seconds
./start_true_headed_server.sh
```

### Profile Issues

**Problem**: Chrome profiles not accessible
**Root Cause**: Profiles require browser-level configuration, not context-level
**Current Limitation**: WebSocket server approach doesn't support profile launching
**Workaround**: Use `start_chromium.ps1` to manually configure Playwright's Chromium profile

**Problem**: Profile directory not found
**Solution**: 
```bash
# List available profiles
powershell.exe -ExecutionPolicy Bypass -File ./list_chrome_profiles.ps1

# Verify Chrome installation
powershell.exe -Command "Get-Command chrome -ErrorAction SilentlyContinue"
```

### Performance Issues

**Problem**: Slow startup/connection (>10 seconds)
**Root Cause**: Port discovery scanning multiple endpoints
**Solution**: Use direct endpoint to skip discovery:
```bash
# Get endpoint from server startup logs
./start_true_headed_server.sh
# Look for: ws://localhost:62426/abc123

# Use directly
PLAYWRIGHT_WS_ENDPOINT=ws://172.19.176.1:62426/abc123 ./playwriter --windows-browser https://google.com
```

**Problem**: Browser windows opening slowly
**Root Cause**: Windows browser initialization, extensions, startup pages
**Solution**: This is normal for headed browsers; headless browsers start faster

### Development Issues

**Problem**: Mix compilation errors
**Solution**: 
```bash
mix deps.clean --all
mix deps.get
mix compile
```

**Problem**: Pattern matching errors in CLI
**Root Cause**: Argument parsing falling through to wrong patterns
**Debug**: Add temporary logging to `cli.ex`:
```elixir
def main(args) do
  IO.puts("DEBUG: args = #{inspect(args)}")
  case args do
    # ... existing patterns
  end
end
```

## Technical Limitations & Future Enhancements

### Current Limitations

1. **Profile Support**: Limited to default Chromium profile due to server architecture constraints
2. **Single Server Instance**: One server per port limits concurrent browser sessions  
3. **Network Dependency**: Requires stable WSL-Windows networking
4. **Manual Server Management**: User must start/stop servers manually
5. **Error Recovery**: Manual intervention required on server crashes

### Planned Enhancements

1. **Profile-Aware Server Launching**: 
   ```javascript
   // Future implementation
   const browserServer = await chromium.launchServer({
     headless: false,
     args: ['--user-data-dir=' + profilePath]
   });
   ```

2. **Server Pool Management**: Multiple servers for concurrent operations
3. **Enhanced Error Recovery**: Automatic server restart and reconnection
4. **Chrome Extension Support**: Install and manage browser extensions programmatically
5. **Session Persistence**: Save and restore complete browser sessions

### Architecture Improvements

1. **Service-Based Architecture**: Windows service for permanent server management
2. **Load Balancing**: Distribute requests across multiple browser instances  
3. **Health Monitoring**: Server health checks and automatic failover
4. **Configuration Management**: Profile and server configuration via config files

## Dependencies

### Elixir Dependencies
- **playwright**: `~> 1.49.1-alpha.2` (Elixir Playwright library)

### System Dependencies  
- **Node.js**: Required on Windows for Playwright server
- **PowerShell**: Used for Windows automation scripts
- **WSL2**: For cross-platform integration (if using Windows)

### Browser Dependencies
- **Chromium**: Downloaded automatically by Playwright
- **Chrome**: Optional, for profile integration
- **Firefox**: Supported but less tested

## Contributing

### Development Workflow

1. **Test both modes**: Always test local Playwright and Windows integration
2. **Update documentation**: Document new CLI options, scripts, and modules  
3. **Handle errors gracefully**: Network issues are common in WSL environments
4. **Clean up resources**: Always close browsers, contexts, and servers
5. **Follow naming conventions**: Use descriptive names for scripts and functions

### Code Standards

```elixir
# Good: Descriptive function names
def connect_windows_browser(browser_type, opts)

# Good: Comprehensive error handling  
case Playwright.Page.goto(page, url, options) do
  %Playwright.Response{} = response -> handle_success(response)
  {:error, error} -> handle_error(error)
end

# Good: Detailed logging
Logger.info("Starting navigation to #{url} with options: #{inspect(options)}")
```

### Testing Requirements

- Test on both WSL and native Linux
- Verify Windows integration end-to-end
- Test error scenarios (network failures, server crashes)
- Validate profile enumeration on different Windows configurations

## Security Considerations

### Network Security
- WebSocket connections are unencrypted (ws:// not wss://)
- Servers bind to all interfaces (potential security risk)
- No authentication on WebSocket connections

### Process Security
- PowerShell execution with `-ExecutionPolicy Bypass`
- Node.js processes running with user privileges
- Browser processes have access to user data

### Recommendations
- Run only on trusted networks (development environments)
- Consider firewall rules for production deployments
- Regular cleanup of temporary files and processes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

- **Author**: [NSHkr](https://github.com/nshkrdotcom)
- **Repository**: https://github.com/nshkrdotcom/playwriter
- **Hex Package**: https://hex.pm/packages/playwriter
- **Documentation**: https://hexdocs.pm/playwriter

## Acknowledgments

- [Playwright](https://playwright.dev/) - The browser automation framework that powers this library
- [Playwright for Elixir](https://github.com/geometerio/playwright-elixir) - The Elixir implementation we build upon
- [Elixir](https://elixir-lang.org/) - The fantastic programming language
- WSL team at Microsoft for enabling seamless cross-platform development

## Support

For issues, questions, and contributions:

1. **Issues**: [GitHub Issues](https://github.com/nshkrdotcom/playwriter/issues)
2. **Documentation**: [HexDocs](https://hexdocs.pm/playwriter)
3. **Discussions**: [GitHub Discussions](https://github.com/nshkrdotcom/playwriter/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.

---

**Note**: This is an advanced browser automation system with cross-platform capabilities. The Windows integration is particularly complex due to the WSL-Windows networking bridge and the requirement for headed browser support. Always test thoroughly in your specific environment.

**Version**: 0.0.1 | **Author**: NSHkr | **License**: MIT