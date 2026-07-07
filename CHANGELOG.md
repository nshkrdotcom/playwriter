# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-07-07

### Fixed
- `:windows` transport Windows-account detection. The transport locates its
  script dir under `C:\Users\<user>\AppData\Local\Temp`, but the user was
  detected by taking the first plausible `/mnt/c/Users/` entry - on machines
  with more than one real account (e.g. a sandbox account that sorts first)
  it picked the wrong user and failed with a permission error. Resolution is
  now: `config :playwriter, :windows_user` (new explicit override) ->
  PowerShell `$env:USERNAME` (authoritative for the live session) -> the old
  directory heuristic as a last resort.

## [0.2.0] - 2026-07-06

Adds the browser-automation surface a dev/test harness needs: arbitrary JS
evaluation, predicate waiting, context init scripts, CDP-based network fault
injection, a clean binary-return contract, and (experimental) page-to-Elixir
bindings. Every new verb is a transport-behaviour callback implemented across
`:windows`, `:local`, and `:remote`.

### Added
- New transport callbacks + `Playwriter.Browser.Session` functions:
  - `evaluate/4` - run arbitrary JavaScript in a page's main frame and get the
    serialized result (`{"json": v}` envelope on the Windows wire protocol,
    `PlaywrightEx.Frame.evaluate/2` on `:local`).
  - `wait_for_function/4` - block until a JavaScript predicate is truthy
    (`:polling`/`:timeout` options).
  - `add_init_script/4` - install a context-scoped script that runs before any
    page script on every page/navigation (must precede `new_page`).
  - `add_cookies/3` + `storage_state/2` - seed a context's cookies (e.g. a
    pre-signed session cookie, to start a test past an auth gate without driving
    the login UI) and capture its storage state (cookies + localStorage) for
    reuse. Full on `:windows` and `:local`.
  - `new_cdp_session/2` + `cdp_send/4` - open a Chrome DevTools Protocol session
    for a page and send CDP commands (e.g. `Network.emulateNetworkConditions`,
    `Network.setBlockedURLs`). **Windows transport only**; `:local` returns
    `{:error, :not_supported}` (playwright_ex exposes no CDP surface).
  - `expose_binding/4` - **experimental**, Windows-only: let a page call back
    into Elixir via `window.<name>(...args)`. Uses a new bidirectional binding
    event on the stdio bridge. The request/response verbs are unaffected; the
    full page-to-Elixir round trip is validated on a Windows box (see the
    `:requires_windows_server` tests). Prefer polling with `evaluate/4` +
    `wait_for_function/4` where possible.
- Thin `Playwriter.evaluate/3` and `Playwriter.wait_for_function/3` facade
  wrappers for use inside `with_browser/2`.
- Explicit `{"value_b64": ...}` binary-return contract (see Changed).
- `Playwriter.Browser.Session` accepts a `:transport_module` option to inject a
  custom transport (used to unit-test dispatch with a Mox behaviour mock).
- `AGENTS.md` - working guide for agents/contributors; shipped in the hex package.
- Committed `package.json` pinning the Node Playwright driver, plus reproducible
  `mix playwriter.setup` provisioning (`npm ci` + `npx playwright install`).

### Changed
- **Binary returns are now explicit.** The Windows transport returns screenshots
  (and any binary) as `{"value_b64": <base64>}`, decoded with `Base.decode64!/1`.
  This replaces the fragile magic-byte sniffing in `process_result/1` that
  guessed whether a `{"value": ...}` string was a PNG/JPEG or HTML. `{"value"}`
  is now always a plain string (`content`).
- The Windows transport reads its stdio stream with proper line-buffering, so
  multiple JSON messages in one chunk (and partial lines split across chunks)
  are handled, and unsolicited `binding` events are routed rather than dropped.
- The `:local` transport resolves its Node Playwright driver from
  `PLAYWRIGHT_CLI` / `config :playwriter, :playwright_cli` /
  `node_modules/playwright/cli.js` instead of a fixed hex-package path, so the
  driver is provisioned reproducibly.
- `Playwriter.Transport.WindowsCmd` is now documented in the generated docs
  (`groups_for_modules`).

### Dependencies
- Bumped `playwright_ex` `~> 0.3.2` -> `~> 0.7` (0.7.1). This provides native
  `Frame.wait_for_function/2` and `BrowserContext.add_init_script/2` helpers, so
  the `:local` implementations use first-class calls rather than a raw escape
  hatch. (Adapted `Frame.goto`'s `:wait_until` to the string form 0.5+ requires.)
- Bumped `ex_doc` `~> 0.34` -> `~> 0.40` (0.40.3), and `credo`/`jason`/
  `supertester`/`mox` constraints to current.
- **Removed `websockex`** - it only served the dead `:remote` WebSocket transport
  (Hyper-V-firewall-blocked) and nothing else used it. (It also blocked
  compilation on recent Elixir/OTP.)
- The embedded Windows-side npm Playwright pin moved `^1.40.0` -> `^1.49.0`.

## [0.1.0] - 2026-02-03

### Changed
- Complete architecture redesign with clean, modular transport abstraction
- New dependency: built on playwright_ex (~> 0.3.2) instead of alpha playwright
- Transport abstraction via Playwriter.Transport.Behaviour
- Session management via Playwriter.Browser.Session GenServer
- Remote transport disabled due to WSL2 Hyper-V firewall blocking WebSockets
- Playwright path changed from deps/playwright_ex to deps/playwright/priv/static
- mix playwriter.setup now installs to correct playwright dependency location
- GenServer call timeouts increased throughout for reliability
- Screenshot handling now properly decodes base64 from playwright_ex
- Server scripts bind to 0.0.0.0 for WSL2 accessibility
- PowerShell commands now use -ExecutionPolicy Bypass flag

### Added
- WindowsCmd transport (Playwriter.Transport.WindowsCmd):
  - Runs Playwright directly on Windows via PowerShell stdin/stdout
  - Bypasses all WSL2 networking and firewall issues
  - No server setup required, just npm install playwright on Windows
  - Use with mode: :windows option
- Transport layer modules:
  - Playwriter.Transport.Local wraps playwright_ex for local automation
  - Playwriter.Transport.WindowsCmd for WSL-to-Windows via PowerShell
  - Playwriter.Transport factory with auto-detection
- Server discovery and health checks:
  - Playwriter.Server.Discovery for automatic endpoint detection
  - Playwriter.Server.Health for availability monitoring
- Public API functions:
  - Playwriter.with_browser/2 for composable sessions with cleanup
  - Playwriter.fetch_html/2, screenshot/2 convenience functions
  - Playwriter.goto/3, content/1, click/3, fill/4 context operations
- Windows server scripts in priv/scripts/
- Working examples in examples/ directory:
  - fetch_html.exs, screenshot.exs, interaction.exs
  - windows_browser.exs, windows_mode.exs, test_windows_cmd.exs
- Test suite with 47 tests using Supertester patterns

### Added Documentation
- Testing guide (guides/testing.md):
  - Test categories and tags explained
  - Running unit, integration, and Windows server tests
  - Prerequisites for each test type
  - CI configuration guidance
  - Writing tests with proper tags
- Examples README (examples/README.md):
  - All available examples with descriptions
  - CLI flags (--local, --remote, --endpoint, --headless)
  - Mode auto-detection behavior
  - Writing custom scripts
  - Troubleshooting tips
- Complete guide system:
  - Getting Started, Architecture, Transport Layer
  - WSL-Windows Integration, Function Reference
  - Examples, Troubleshooting
- HexDocs configuration with grouped modules and guide hierarchy
- Professional hexagonal SVG logo

### Removed
- Old Playwriter.Fetcher module (replaced by Session)
- Old Playwriter.WindowsBrowserAdapter (replaced by transports)
- Old Playwriter.WindowsBrowserDirect (experimental)
- Old Playwriter.CLI (simplified, to be re-added)
- Dependency on alpha playwright library
- Remote transport WebSocket implementation (non-functional in WSL2)

### Fixed
- Screenshot binary handling with proper base64 decoding
- Timeout issues in browser operations
- PowerShell execution policy blocking script execution
- Server not accepting connections from WSL2

### Cleanup
- Removed 44 unused files from root directory
- Clean root: LICENSE, CHANGELOG.md, README.md only
- Development scripts consolidated in priv/scripts/
- Added screenshot.png to .gitignore

### Technical
- Zero compiler warnings
- Credo strict: no issues
- Dialyzer clean
- All unit tests passing

## [0.0.2] - 2025-07-04

### Added
- **Architecture Diagrams**: Comprehensive Mermaid diagrams documenting system architecture
- **Visual Documentation**: Added `diagrams.md` with 10 detailed diagrams covering:
  - High-Level Architecture overview
  - WSL-to-Windows Bridge Flow
  - Component Interaction patterns
  - WebSocket Connection Workflow
  - Browser Launch Strategies
  - Data Flow visualization
  - Error Handling Flow
  - Chrome Profile Integration
  - Security Considerations
  - Performance Optimization strategies

### Changed
- **Documentation**: Enhanced Hex.pm documentation package with visual diagrams
- **Styling**: All Mermaid diagrams now use consistent black font color (#000) for better readability
- **HexDocs**: Added native Mermaid diagram rendering support with automatic dark/light theme switching

## [0.0.1] - 2025-07-04

### Added

#### Core Features
- **Cross-Platform Browser Automation**: Complete Elixir application for browser automation using Playwright
- **WSL-to-Windows Integration**: Advanced WebSocket-based bridge for controlling Windows browsers from WSL
- **Headed Browser Support**: True visible browser windows (not just headless automation)
- **Multi-Port Discovery**: Robust server discovery across multiple ports and network interfaces
- **Chrome Profile Integration**: Support for enumerating and accessing Windows Chrome profiles

#### CLI Interface
- **Flexible Command System**: Multiple operation modes with pattern matching
- **Local Browser Automation**: Standard Playwright automation in headless/headed modes
- **Windows Browser Commands**: `--windows-browser` and `--windows-firefox` options
- **Profile Management**: `--list-profiles` command for Chrome profile enumeration
- **Authentication Demo**: `--auth` mode with custom headers and cookies

#### Core Modules
- **Playwriter.Fetcher**: Core HTML fetching logic with dual-mode browser management
- **Playwriter.WindowsBrowserAdapter**: WSL-Windows WebSocket bridge with network discovery
- **Playwriter.WindowsBrowserDirect**: Alternative direct browser control methods
- **Playwriter.CLI**: Command-line interface with comprehensive argument parsing

#### Windows Integration Scripts
- **start_true_headed_server.sh**: Launch headed Playwright server on Windows
- **kill_playwright.ps1**: Clean termination of all Playwright processes
- **list_chrome_profiles.ps1**: Enumerate available Chrome profiles on Windows
- **start_chromium.ps1**: Launch Playwright's Chromium with custom profile setup

#### Network & Discovery
- **Multi-Endpoint Discovery**: Automatic WSL gateway IP detection and fallback
- **Port Scanning**: Intelligent port discovery with prioritization
- **Connection Validation**: Server health checking and endpoint verification
- **Error Recovery**: Graceful handling of network failures and timeouts

#### Documentation
- **Comprehensive README**: Detailed developer documentation with architecture diagrams
- **Code Examples**: Usage examples for both CLI and programmatic access
- **Troubleshooting Guide**: Extensive troubleshooting section with common issues
- **Architecture Documentation**: Deep-dive into cross-platform integration

### Technical Details

#### Architecture Innovations
- **WebSocket Bridge**: Solves WSL-Windows network boundary challenges
- **Headed Server Architecture**: Uses `launchServer({headless: false})` instead of `run-server`
- **Profile Discovery**: PowerShell-based Chrome profile enumeration
- **Process Management**: Clean startup, shutdown, and cleanup utilities

#### Supported Platforms
- **WSL2**: Primary development and testing environment
- **Windows**: Target platform for browser automation
- **Linux**: Native support for local browser automation

#### Browser Support
- **Chromium**: Primary browser with full feature support
- **Chrome**: Profile integration and Windows-specific features
- **Firefox**: Basic support through Windows integration

#### Dependencies
- **Elixir**: 1.14+ compatibility
- **Playwright**: 1.49.1-alpha.2 (Elixir port)
- **Node.js**: Required on Windows for Playwright server
- **PowerShell**: Used for Windows automation scripts

### Known Limitations

#### Current Constraints
- **Profile Support**: Limited to default Chromium profile due to server architecture
- **Single Server**: One server per port limits concurrent browser sessions
- **Manual Management**: User must start/stop servers manually
- **Network Dependency**: Requires stable WSL-Windows networking

#### Security Considerations
- **Unencrypted WebSocket**: Uses ws:// not wss:// connections
- **No Authentication**: WebSocket connections have no authentication
- **Process Privileges**: Runs with user-level privileges

### Future Roadmap

#### Planned Enhancements
- **Profile-Aware Servers**: Launch servers with specific Chrome profile arguments
- **Server Pool Management**: Multiple servers for concurrent operations
- **Enhanced Error Recovery**: Automatic server restart and reconnection
- **Chrome Extension Support**: Install and manage browser extensions
- **Session Persistence**: Save and restore complete browser sessions

#### Architecture Improvements
- **Service-Based Architecture**: Windows service for permanent server management
- **Load Balancing**: Distribute requests across multiple browser instances
- **Health Monitoring**: Server health checks and automatic failover
- **Configuration Management**: Profile and server configuration via config files

### Credits

- **Author**: NSHkr
- **Repository**: https://github.com/nshkrdotcom/playwriter
- **Hex Package**: https://hex.pm/packages/playwriter
- **License**: MIT License

### Acknowledgments

- [Playwright](https://playwright.dev/) - The browser automation framework
- [Playwright for Elixir](https://github.com/geometerio/playwright-elixir) - The Elixir implementation
- [Elixir](https://elixir-lang.org/) - The programming language
- WSL team at Microsoft for cross-platform development capabilities