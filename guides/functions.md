# Function Reference

Complete documentation for the Playwriter public API.

## Main Module: `Playwriter`

### with_browser/2

Execute a function with a managed browser session.

```elixir
@spec with_browser(keyword(), (context() -> result)) :: {:ok, result} | {:error, term()}
```

**Parameters:**
- `opts` - Keyword list of options
- `fun` - Function that receives the browser context

**Options:**
- `:mode` - `:local` (default) or `:remote`
- `:browser_type` - `:chromium` (default), `:firefox`, or `:webkit`
- `:headless` - `true` (default) or `false`
- `:ws_endpoint` - WebSocket URL for remote mode
- `:timeout` - Operation timeout in milliseconds (default: 30000)

**Returns:**
- `{:ok, result}` - The return value of the function
- `{:error, reason}` - If an error occurred

**Example:**
```elixir
{:ok, titles} = Playwriter.with_browser([headless: false], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://news.ycombinator.com")
  {:ok, html} = Playwriter.content(ctx)

  html
  |> Floki.parse_document!()
  |> Floki.find(".titleline > a")
  |> Enum.map(&Floki.text/1)
end)
```

### fetch_html/2

Fetch HTML content from a URL.

```elixir
@spec fetch_html(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
```

**Parameters:**
- `url` - The URL to fetch
- `opts` - Options (same as `with_browser/2`)

**Example:**
```elixir
{:ok, html} = Playwriter.fetch_html("https://example.com")
{:ok, html} = Playwriter.fetch_html("https://example.com", headless: false)
```

### screenshot/2

Take a screenshot of a URL.

```elixir
@spec screenshot(String.t(), keyword()) :: {:ok, binary()} | {:error, term()}
```

**Parameters:**
- `url` - The URL to screenshot
- `opts` - Options including:
  - `:full_page` - Capture full scrollable page (default: false)
  - `:type` - `:png` (default) or `:jpeg`
  - `:quality` - JPEG quality 0-100 (only for `:jpeg`)
  - All `with_browser/2` options

**Example:**
```elixir
{:ok, png_data} = Playwriter.screenshot("https://example.com")
File.write!("screenshot.png", png_data)

# Full page screenshot
{:ok, full} = Playwriter.screenshot("https://example.com", full_page: true)
```

### goto/3

Navigate to a URL within a browser session.

```elixir
@spec goto(context(), String.t(), keyword()) :: :ok | {:error, term()}
```

**Parameters:**
- `ctx` - Browser context from `with_browser/2`
- `url` - URL to navigate to
- `opts` - Navigation options:
  - `:timeout` - Navigation timeout in ms
  - `:wait_until` - `:load`, `:domcontentloaded`, `:networkidle`

**Example:**
```elixir
Playwriter.with_browser([], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")
  :ok = Playwriter.goto(ctx, "https://example.com/page2", wait_until: :networkidle)
end)
```

### content/1

Get the full HTML content of the current page.

```elixir
@spec content(context()) :: {:ok, String.t()} | {:error, term()}
```

**Parameters:**
- `ctx` - Browser context from `with_browser/2`

**Example:**
```elixir
Playwriter.with_browser([], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")
  {:ok, html} = Playwriter.content(ctx)
  String.contains?(html, "Example Domain")
end)
```

### click/3

Click an element matching a selector.

```elixir
@spec click(context(), String.t(), keyword()) :: :ok | {:error, term()}
```

**Parameters:**
- `ctx` - Browser context
- `selector` - CSS selector or text selector
- `opts` - Click options:
  - `:timeout` - Wait timeout for element
  - `:button` - `:left`, `:right`, or `:middle`
  - `:click_count` - Number of clicks (default: 1)
  - `:delay` - Time between mousedown and mouseup in ms

**Selectors:**
```elixir
# CSS selectors
Playwriter.click(ctx, "button.submit")
Playwriter.click(ctx, "#login-button")
Playwriter.click(ctx, "form input[type=submit]")

# Text selectors
Playwriter.click(ctx, "text=Sign In")
Playwriter.click(ctx, "text=Click here")
```

**Example:**
```elixir
Playwriter.with_browser([], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")
  :ok = Playwriter.click(ctx, "a")  # Click first link
end)
```

### fill/4

Fill an input field with text.

```elixir
@spec fill(context(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
```

**Parameters:**
- `ctx` - Browser context
- `selector` - Input element selector
- `value` - Text to fill
- `opts` - Fill options:
  - `:timeout` - Wait timeout for element

**Example:**
```elixir
Playwriter.with_browser([], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com/login")
  :ok = Playwriter.fill(ctx, "#username", "myuser")
  :ok = Playwriter.fill(ctx, "#password", "mypass")
  :ok = Playwriter.click(ctx, "button[type=submit]")
end)
```

### version/0

Returns the Playwriter version.

```elixir
@spec version() :: String.t()
```

**Example:**
```elixir
Playwriter.version()
# => "0.1.0"
```

## Context Structure

The context passed to `with_browser/2` callbacks contains:

```elixir
%{
  session: pid(),      # Browser session GenServer
  page: String.t(),    # Page GUID for operations
  frame: String.t()    # Main frame GUID
}
```

You typically don't need to access these directly; pass the context to Playwriter functions.

## Server Discovery: `Playwriter.Server.Discovery`

### discover/1

Automatically find a running Playwright server.

```elixir
@spec discover(keyword()) :: {:ok, String.t()} | {:error, :not_found}
```

**Options:**
- `:ports` - List of ports to try (default: [3337, 3336, 3335, 3334, 9222])
- `:hosts` - List of hosts to try
- `:timeout` - Connection timeout per attempt

**Example:**
```elixir
{:ok, endpoint} = Playwriter.Server.Discovery.discover()
# => {:ok, "ws://172.25.160.1:3337/"}

# Custom ports
{:ok, endpoint} = Playwriter.Server.Discovery.discover(ports: [9222])
```

### get_wsl2_host_ip/0

Get the Windows host IP from WSL.

```elixir
@spec get_wsl2_host_ip() :: {:ok, String.t()} | {:error, term()}
```

**Example:**
```elixir
{:ok, ip} = Playwriter.Server.Discovery.get_wsl2_host_ip()
# => {:ok, "172.25.160.1"}
```

## Browser Session: `Playwriter.Browser.Session`

Low-level session management. Typically you don't use this directly.

### start_link/1

Start a browser session.

```elixir
@spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
```

### get_page/1

Get the current page GUID.

```elixir
@spec get_page(pid()) :: {:ok, String.t()} | {:error, term()}
```

### stop/1

Stop a browser session.

```elixir
@spec stop(pid()) :: :ok
```

## Transport Behaviour

Both local and remote transports implement `Playwriter.Transport.Behaviour`:

```elixir
@callback start_link(keyword()) :: {:ok, pid()} | {:error, term()}
@callback launch_browser(transport(), browser_type(), keyword()) :: {:ok, guid()}
@callback new_context(transport(), guid(), keyword()) :: {:ok, guid()}
@callback new_page(transport(), guid()) :: {:ok, map()}
@callback goto(transport(), guid(), String.t(), keyword()) :: result()
@callback content(transport(), guid()) :: {:ok, String.t()}
@callback click(transport(), guid(), String.t(), keyword()) :: result()
@callback fill(transport(), guid(), String.t(), String.t(), keyword()) :: result()
@callback screenshot(transport(), guid(), keyword()) :: {:ok, binary()}
@callback close_browser(transport(), guid()) :: :ok
```

## Error Handling

All functions return `{:ok, result}` or `{:error, reason}` tuples.

Common error reasons:
- `:timeout` - Operation timed out
- `:not_found` - Element or server not found
- `{:navigation_failed, reason}` - Page navigation failed
- `{:connection_error, reason}` - WebSocket connection failed

**Example:**
```elixir
case Playwriter.fetch_html(url) do
  {:ok, html} ->
    process_html(html)

  {:error, :timeout} ->
    Logger.warning("Request timed out")
    {:error, :timeout}

  {:error, reason} ->
    Logger.error("Failed: #{inspect(reason)}")
    {:error, reason}
end
```

## Type Specifications

```elixir
@type context() :: %{session: pid(), page: String.t(), frame: String.t()}
@type browser_type() :: :chromium | :firefox | :webkit
@type guid() :: String.t()
@type result() :: :ok | {:ok, term()} | {:error, term()}
```
