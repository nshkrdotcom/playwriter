# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-03

### Changed
- **Complete Architecture Redesign**: Rebuilt from the ground up with clean, modular architecture
- **New Dependency**: Now built on `playwright_ex` (~> 0.3.2) instead of the alpha playwright library
- **Transport Abstraction**: Introduced `Playwriter.Transport.Behaviour` with Local and Remote implementations
- **Session Management**: New `Playwriter.Browser.Session` GenServer for browser lifecycle management

### Added
- **Transport Layer**:
  - `Playwriter.Transport.Local` - Wraps playwright_ex for local browser automation
  - `Playwriter.Transport.Remote` - WebSocket transport for Windows Playwright server connection
  - `Playwriter.Transport` - Factory module with auto-detection of best transport
- **Server Discovery**: `Playwriter.Server.Discovery` for automatic WSL-to-Windows server detection
- **Health Checks**: `Playwriter.Server.Health` for server availability monitoring
- **New Public API**:
  - `Playwriter.with_browser/2` - Composable browser session with automatic cleanup
  - `Playwriter.fetch_html/2` - Convenience function for HTML fetching
  - `Playwriter.screenshot/2` - Convenience function for screenshots
  - `Playwriter.goto/3`, `Playwriter.content/1`, `Playwriter.click/3`, `Playwriter.fill/4` - Context-based operations
- **Windows Server Scripts**: Simplified PowerShell and Node.js scripts in `priv/scripts/`
- **Working Examples**: `examples/*.exs` with real runnable examples
- **Test Suite**: Full TDD test suite using Supertester patterns with 47 tests

### Removed
- Old `Playwriter.Fetcher` module (replaced by Session)
- Old `Playwriter.WindowsBrowserAdapter` (replaced by Transport.Remote)
- Old `Playwriter.WindowsBrowserDirect` (experimental, removed)
- Old `Playwriter.CLI` (simplified, will be re-added later)
- Dependency on alpha `playwright` library

### Documentation
- **Complete Documentation Overhaul**: Professional guide system with 7 comprehensive guides
  - Getting Started guide
  - Architecture overview
  - Transport Layer documentation
  - WSL-Windows Integration guide
  - Function Reference
  - Examples with real-world patterns
  - Troubleshooting guide
- **New Logo**: Professional hexagonal SVG logo in `assets/playwriter.svg`
- **Revamped README**: Cohesive user story focused on the WSL-to-Windows use case
- **HexDocs Configuration**: Grouped modules, guide hierarchy, and logo integration

### Cleanup
- Removed 44 unused files from root directory (debug scripts, test scripts, old docs)
- Clean root structure: only LICENSE, CHANGELOG.md, README.md remain as docs
- All development scripts moved to `priv/scripts/`

### Technical
- Zero compiler warnings
- Credo strict: no issues
- Dialyzer clean
- All unit tests passing (47 tests)

## [0.0.2] - 2025-01-05

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

## [0.0.1] - 2025-01-05

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