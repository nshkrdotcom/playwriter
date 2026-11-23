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
- `:mode` - `:local` (default) or `:windows`
- `:browser_type` - `:chromium` (default), `:firefox`, or `:webkit` in local mode. See [Windows browser selection](wsl-windows.md#2-choose-and-verify-a-windows-browser) for Windows mode.
- `:headless` - Defaults to `true` in local mode and `false` in Windows mode.

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
- `opts` - Options from `with_browser/2`, plus the navigation `:timeout` and, in local mode, `:wait_until`.

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
  - `:full_page` - Capture the full scrollable page in local mode (default: false)
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
  - `:wait_until` (local mode) - `:load`, `:domcontentloaded`, `:networkidle`, or `:commit`

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
# => "0.4.0"
```

## Context Structure

The context passed to `with_browser/2` callbacks contains:

```elixir
%{
  session: pid(),      # Browser session GenServer
  page: String.t()     # Session page ID
}
```

You typically don't need to access these directly; pass the context to Playwriter functions.

## Server Discovery: `Playwriter.Server.Discovery`

### discover/1

Find a running legacy WebSocket endpoint. The supported local and Windows transports use their own driver processes.

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
@spec get_wsl2_host_ip() :: String.t() | nil
```

**Example:**
```elixir
Playwriter.Server.Discovery.get_wsl2_host_ip()
# => "172.25.160.1" or nil
```

## Browser Session: `Playwriter.Browser.Session`

Low-level session management. Typically you don't use this directly.

### start_link/1

Start a browser session.

```elixir
@spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
```

### new_page/2

Create a page in the session. The second argument is an optional keyword list.
Use the returned page ID with session operations.

```elixir
{:ok, page} = Playwriter.Browser.Session.new_page(session)
```

### close/1

Close the session and release its browser resources.

```elixir
:ok = Playwriter.Browser.Session.close(session)
```

## Transport Behaviour

The local and Windows transports implement `Playwriter.Transport.Behaviour`:

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

Browser operations generally return `:ok`, `{:ok, result}`, or `{:error, reason}`. The error reason can vary by transport and operation.

**Example:**
```elixir
case Playwriter.fetch_html(url) do
  {:ok, html} ->
    process_html(html)

  {:error, reason} ->
    Logger.error("Failed: #{inspect(reason)}")
    {:error, reason}
end
```

## Type Specifications

```elixir
@type context() :: %{session: pid(), page: String.t()}
@type browser_type() :: :chromium | :firefox | :webkit
@type guid() :: String.t()
@type result() :: :ok | {:ok, term()} | {:error, term()}
```
