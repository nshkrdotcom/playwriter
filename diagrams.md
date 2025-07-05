# Playwriter Architecture Diagrams

This document provides visual representations of Playwriter's architecture and workflows using Mermaid diagrams.

## Table of Contents
- [High-Level Architecture](#high-level-architecture)
- [WSL-to-Windows Bridge Flow](#wsl-to-windows-bridge-flow)
- [Component Interaction](#component-interaction)
- [WebSocket Connection Workflow](#websocket-connection-workflow)
- [Browser Launch Strategies](#browser-launch-strategies)
- [Data Flow Diagram](#data-flow-diagram)

## High-Level Architecture

```mermaid
graph TB
    subgraph "WSL Environment"
        A[Elixir App<br/>Playwriter]
        B[Playwright<br/>Elixir Library]
        C[WindowsBrowserAdapter]
    end
    
    subgraph "Windows Environment"
        D[Playwright Server<br/>Node.js]
        E[Chrome Browser]
        F[Firefox Browser]
        G[Edge Browser]
    end
    
    subgraph "Connection Layer"
        H[WebSocket<br/>ws://localhost:3337]
    end
    
    A --> B
    B --> C
    C -->|Connect via| H
    H -->|Control| D
    D -->|Launch & Control| E
    D -->|Launch & Control| F
    D -->|Launch & Control| G
    
    style A fill:#e1f5fe,color:#000
    style B fill:#b3e5fc,color:#000
    style C fill:#81d4fa,color:#000
    style D fill:#fff9c4,color:#000
    style E fill:#ffeb3b,color:#000
    style F fill:#ffc107,color:#000
    style G fill:#ff9800,color:#000
    style H fill:#c5e1a5,color:#000
```

## WSL-to-Windows Bridge Flow

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryTextColor':'#000'}}}%%
sequenceDiagram
    participant User
    participant CLI as Playwriter CLI
    participant Fetcher
    participant Adapter as WindowsBrowserAdapter
    participant PS as PowerShell
    participant Server as Playwright Server (Windows)
    participant Browser as Windows Browser
    
    User->>CLI: playwriter fetch --use-windows-browser
    CLI->>Fetcher: fetch_html(url, opts)
    
    alt Windows Browser Mode
        Fetcher->>Adapter: connect_windows_browser()
        Adapter->>Adapter: find_working_endpoint()
        
        alt Server Not Running
            Adapter->>User: Display manual start instructions
            User->>PS: ./start_true_headed_server.sh
            PS->>Server: Start Playwright server on port 3337
            Server-->>PS: Server running
        end
        
        Adapter->>Server: WebSocket connect
        Server-->>Adapter: Connected
        Adapter-->>Fetcher: Browser handle
        
        Fetcher->>Browser: new_page()
        Fetcher->>Browser: goto(url)
        Browser-->>Fetcher: Page loaded
        Fetcher->>Browser: content()
        Browser-->>Fetcher: HTML content
        
        Fetcher->>Browser: close()
        Fetcher-->>CLI: HTML result
        CLI-->>User: Display/Save HTML
    else Standard Mode
        Fetcher->>Fetcher: Playwright.launch(:chromium)
        Note over Fetcher: Uses headless browser in WSL
    end
```

## Component Interaction

```mermaid
graph LR
    subgraph "Core Components"
        A[Playwriter.CLI]
        B[Playwriter.Fetcher]
        C[Playwriter.WindowsBrowserAdapter]
        D[Playwriter.WindowsBrowserDirect]
    end
    
    subgraph "External Dependencies"
        E[Playwright Elixir]
        F[WebSocket Transport]
        G[PowerShell Scripts]
    end
    
    subgraph "Browsers"
        H[Local Headless]
        I[Windows Chrome]
        J[Windows Firefox]
    end
    
    A -->|Commands| B
    B -->|Standard| E
    B -->|Windows Mode| C
    C -->|WebSocket| F
    C -->|Utilities| G
    D -->|Direct Control| G
    
    E -->|Launch| H
    F -->|Control| I
    F -->|Control| J
    
    style A fill:#e3f2fd,color:#000
    style B fill:#bbdefb,color:#000
    style C fill:#90caf9,color:#000
    style D fill:#64b5f6,color:#000
    style E fill:#fff3e0,color:#000
    style F fill:#ffe0b2,color:#000
    style G fill:#ffccbc,color:#000
```

## WebSocket Connection Workflow

```mermaid
flowchart TD
    A[Start Connection] --> B{Check ENV<br/>PLAYWRIGHT_WS_ENDPOINT}
    B -->|Set| C[Use ENV Endpoint]
    B -->|Not Set| D[Check opts.ws_endpoint]
    
    D -->|Provided| E[Use Provided Endpoint]
    D -->|Not Provided| F[Find Available Port]
    
    F --> G[Try Ports:<br/>3337, 3336, 3335,<br/>3334, 3333, 9222, 9223]
    
    G --> H{For Each Port}
    H --> I[Generate Possible Endpoints]
    
    I --> J[Check Endpoints:<br/>- ws://localhost:port<br/>- ws://127.0.0.1:port<br/>- ws://windows-host-ip:port<br/>- ws://172.19.176.1:port]
    
    J --> K{Server Found?}
    K -->|Yes| L[Test Playwright Protocol]
    K -->|No| M{More Ports?}
    
    L -->|Valid| N[Connect to Server]
    L -->|Invalid| M
    
    M -->|Yes| H
    M -->|No| O[Show Manual Start Instructions]
    
    C --> N
    E --> N
    N --> P[Return Browser Handle]
    
    style A fill:#e8f5e9,color:#000
    style N fill:#4caf50,color:#000
    style O fill:#ffebee,color:#000
    style P fill:#c8e6c9,color:#000
```

## Browser Launch Strategies

```mermaid
graph TD
    A[Browser Launch Request] --> B{Mode?}
    
    B -->|Standard| C[Local Headless Browser]
    B -->|Windows Browser| D[Remote Windows Browser]
    B -->|Direct PowerShell| E[WindowsBrowserDirect]
    
    C --> F[Playwright.launch]
    F --> G[Headless Chromium in WSL]
    
    D --> H[WindowsBrowserAdapter]
    H --> I{Server Running?}
    I -->|Yes| J[Connect via WebSocket]
    I -->|No| K[Manual Start Required]
    
    E --> L[PowerShell Commands]
    L --> M[Limited Control<br/>No HTML Capture]
    
    J --> N[Full Browser Control]
    N --> O[Page Navigation]
    N --> P[Content Extraction]
    N --> Q[Screenshot Capture]
    
    style A fill:#f3e5f5,color:#000
    style C fill:#e1bee7,color:#000
    style D fill:#ce93d8,color:#000
    style E fill:#ba68c8,color:#000
    style N fill:#4caf50,color:#000
    style M fill:#f44336,color:#000
```

## Data Flow Diagram

```mermaid
flowchart TD
    subgraph "Input"
        A[URL]
        B[Options<br/>- browser type<br/>- headers<br/>- cookies<br/>- viewport]
    end
    
    subgraph "Processing Layer"
        C[Playwriter.Fetcher]
        D[Connection Handler]
        E[Page Controller]
    end
    
    subgraph "Transport"
        F[WebSocket Protocol]
        G[JSON Messages]
    end
    
    subgraph "Execution"
        H[Windows Playwright Server]
        I[Browser Process]
        J[Web Page]
    end
    
    subgraph "Output"
        K[HTML Content]
        L[Screenshots]
        M[Network Data]
    end
    
    A --> C
    B --> C
    C --> D
    D --> F
    F --> G
    G --> H
    H --> I
    I --> J
    J --> K
    J --> L
    J --> M
    
    K --> E
    L --> E
    M --> E
    E --> C
    
    style A fill:#e3f2fd,color:#000
    style B fill:#e3f2fd,color:#000
    style K fill:#c8e6c9,color:#000
    style L fill:#c8e6c9,color:#000
    style M fill:#c8e6c9,color:#000
```

## Error Handling Flow

```mermaid
flowchart TD
    A[Operation Start] --> B{Connection Type}
    
    B -->|WebSocket| C[Try Connection]
    B -->|Direct Launch| D[Launch Browser]
    
    C --> E{Connected?}
    E -->|No| F[Try Alternative Endpoints]
    F --> G{Any Success?}
    G -->|No| H[Show Manual Instructions]
    G -->|Yes| I[Proceed]
    
    E -->|Yes| I[Proceed with Operation]
    
    D --> J{Launch Success?}
    J -->|No| K[Fallback to Headless]
    J -->|Yes| I
    
    I --> L{Page Load}
    L -->|Timeout| M[Retry with Extended Timeout]
    L -->|Error| N[Log Error & Return]
    L -->|Success| O[Extract Content]
    
    M --> P{Retry Success?}
    P -->|No| N
    P -->|Yes| O
    
    O --> Q[Clean Up Resources]
    Q --> R[Return Result]
    
    H --> S[Exit with Instructions]
    N --> Q
    
    style A fill:#e8f5e9,color:#000
    style R fill:#4caf50,color:#000
    style H fill:#ffebee,color:#000
    style S fill:#f44336,color:#000
    style N fill:#ff9800,color:#000
```

## Chrome Profile Integration

```mermaid
sequenceDiagram
    participant User
    participant CLI
    participant Adapter as WindowsBrowserAdapter
    participant PS as PowerShell
    participant Chrome
    
    User->>CLI: Request with --chrome-profile
    CLI->>Adapter: get_chrome_profiles()
    Adapter->>PS: List Chrome profiles
    PS->>PS: Read %LOCALAPPDATA%\Google\Chrome\User Data
    PS-->>Adapter: Profile list
    Adapter-->>CLI: Available profiles
    
    alt Profile Selection
        CLI->>User: Show available profiles
        User->>CLI: Select profile
    end
    
    CLI->>Adapter: connect_windows_browser(profile: selected)
    Adapter->>Chrome: Launch with profile
    Chrome-->>Adapter: Browser instance
    Adapter-->>CLI: Ready for automation
    
    Note over Chrome: Browser runs with<br/>selected profile's<br/>cookies, extensions,<br/>and settings
    
    %%{init: {'theme':'base', 'themeVariables': {'primaryTextColor':'#000'}}}%%
```

## Security Considerations

```mermaid
graph LR
    A[Security Layers] --> B[WSL Isolation]
    A --> C[WebSocket Security]
    A --> D[Process Isolation]
    
    B --> E[Linux Environment<br/>Separated from Windows]
    B --> F[Network Bridge Only]
    
    C --> G[Local-only Connections<br/>127.0.0.1/localhost]
    C --> H[No External Access]
    C --> I[Port Filtering]
    
    D --> J[Separate Browser Process]
    D --> K[Controlled via Protocol]
    D --> L[Clean Resource Management]
    
    style A fill:#ffebee,color:#000
    style B fill:#ffcdd2,color:#000
    style C fill:#ef9a9a,color:#000
    style D fill:#e57373,color:#000
```

## Performance Optimization

```mermaid
flowchart LR
    A[Optimization Strategies] --> B[Connection Reuse]
    A --> C[Parallel Operations]
    A --> D[Resource Management]
    
    B --> E[Keep Server Running]
    B --> F[Connection Pooling]
    
    C --> G[Concurrent Page Operations]
    C --> H[Batch Processing]
    
    D --> I[Automatic Cleanup]
    D --> J[Memory Management]
    D --> K[Process Lifecycle Control]
    
    style A fill:#f3e5f5,color:#000
    style B fill:#e1bee7,color:#000
    style C fill:#ce93d8,color:#000
    style D fill:#ba68c8,color:#000
```

---

These diagrams provide a comprehensive visual overview of Playwriter's architecture, making it easier to understand how the WSL-to-Windows browser automation works. The diagrams can be rendered in any Markdown viewer that supports Mermaid syntax, including GitHub, GitLab, and various documentation tools.