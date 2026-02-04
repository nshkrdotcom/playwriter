# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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