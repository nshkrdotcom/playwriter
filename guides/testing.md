# Testing Guide

This guide covers running and writing tests for Playwriter.

## Quick Start

```bash
# Run unit tests (no browser required)
mix test

# Run all tests (requires setup)
mix playwriter.setup
INTEGRATION=true mix test
```

## Test Categories

Playwriter tests are organized by what infrastructure they require:

| Tag | Requires | Run With |
|-----|----------|----------|
| (none) | Nothing | `mix test` |
| `:requires_browser` | Local Playwright | `INTEGRATION=true mix test` |
| `:requires_windows_server` | Windows server | `WINDOWS_SERVER=true mix test` |
| `:wsl_only` | WSL environment | `WINDOWS_SERVER=true mix test` |
| `:integration` | Local Playwright | `INTEGRATION=true mix test` |

## Running Tests

### Unit Tests (Default)

Unit tests use mocks and don't require any browser infrastructure:

```bash
mix test
```

These tests verify:
- Option parsing and validation
- Error handling logic
- Module interfaces
- Discovery algorithms (mocked)

### Integration Tests

Integration tests launch real browsers and require Playwright installed:

```bash
# First, install Playwright
mix playwriter.setup

# Run integration tests
INTEGRATION=true mix test
```

These tests verify:
- Local transport browser launching
- Page navigation and content fetching
- Screenshots and interactions
- Session lifecycle management

### Windows Server Tests

These tests connect to a Windows Playwright server:

```bash
# 1. Start the server on Windows
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1

# 2. Run tests from WSL
WINDOWS_SERVER=true mix test
```

These tests verify:
- Remote transport WebSocket connection
- WSL-to-Windows communication
- Server discovery
- Cross-platform browser control

### All Tests

To run the complete test suite:

```bash
# 1. Install local Playwright
mix playwriter.setup

# 2. Start Windows server (if testing remote mode)
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1

# 3. Run all tests
INTEGRATION=true WINDOWS_SERVER=true mix test
```

## Test Infrastructure Setup

### Local Playwright Setup

```bash
# Install Playwright and Chromium
mix playwriter.setup

# Or install specific browsers
mix playwriter.setup --browser firefox
mix playwriter.setup --browser all

# If you see browser launch errors on Linux
cd deps/playwright_ex && npx playwright install-deps chromium
```

### Windows Server Setup

On Windows, you need Node.js and Playwright:

```powershell
# Install Node.js if needed
winget install OpenJS.NodeJS.LTS

# Create server directory (one-time)
mkdir C:\playwright-server
cd C:\playwright-server
npm init -y
npm install playwright
npx playwright install chromium

# Start server (each session)
npx playwright run-server --port 3337
```

Or use the provided script:

```powershell
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1
```

## Writing Tests

### Unit Tests (No Browser)

Use Mox to mock the transport layer:

```elixir
defmodule MyTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "handles errors gracefully" do
    # Test logic without needing a real browser
    assert {:error, _} = Playwriter.fetch_html("invalid://url")
  end
end
```

### Integration Tests (Requires Browser)

Tag tests that need a real browser:

```elixir
defmodule BrowserTest do
  use ExUnit.Case

  @tag :requires_browser
  test "fetches real page content" do
    {:ok, html} = Playwriter.fetch_html("https://example.com")
    assert html =~ "Example Domain"
  end
end
```

### Windows Server Tests

Tag tests that need the Windows server:

```elixir
defmodule RemoteTest do
  use ExUnit.Case

  @tag :requires_windows_server
  test "connects to Windows browser" do
    {:ok, html} = Playwriter.fetch_html("https://example.com", mode: :remote)
    assert html =~ "Example Domain"
  end
end
```

### WSL-Only Tests

For tests that only make sense in WSL:

```elixir
@tag :wsl_only
@tag :requires_windows_server
test "discovers Windows server from WSL" do
  {:ok, endpoint} = Playwriter.Server.Discovery.discover()
  assert endpoint =~ "ws://"
end
```

## Continuous Integration

For CI environments, only unit tests run by default:

```yaml
# .github/workflows/test.yml
- name: Run tests
  run: mix test
```

To run integration tests in CI, you'd need to install Playwright:

```yaml
- name: Setup Playwright
  run: mix playwriter.setup

- name: Run integration tests
  run: INTEGRATION=true mix test
```

## Test File Structure

```
test/
├── test_helper.exs              # Test configuration
├── support/
│   └── fixtures.ex              # Test fixtures and helpers
├── playwriter_test.exs          # Main module tests
└── playwriter/
    ├── browser/
    │   └── session_test.exs     # Session GenServer tests
    ├── server/
    │   └── discovery_test.exs   # Server discovery tests
    └── transport/
        ├── local_test.exs       # Local transport tests
        └── remote_test.exs      # Remote transport tests
```

## Troubleshooting Tests

### "Playwright executable not found"

```bash
mix playwriter.setup
```

### "No Playwright server found"

Start the Windows server:

```powershell
powershell.exe -ExecutionPolicy Bypass -File priv/scripts/start_server.ps1
```

### Tests hang or timeout

- Check that no zombie browser processes are running
- Increase timeout: `@tag timeout: 60_000`
- Try running with `--trace` for more output

### Flaky tests

Browser tests can be flaky due to timing. Use:

```elixir
# Wait for element
Process.sleep(1000)

# Or increase operation timeout
Playwriter.click(ctx, "button", timeout: 10_000)
```
