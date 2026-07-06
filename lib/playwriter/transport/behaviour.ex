defmodule Playwriter.Transport.Behaviour do
  @moduledoc """
  Behaviour defining the transport interface for Playwright communication.

  Transports abstract how Playwriter communicates with Playwright:
  - `Playwriter.Transport.Local` - Uses playwright_ex with Erlang Ports
  - `Playwriter.Transport.Remote` - Uses WebSocket to remote Playwright server
  """

  @type transport :: pid() | GenServer.server()
  @type guid :: String.t()
  @type message :: map()
  @type browser_type :: :chromium | :firefox | :webkit
  @type result :: {:ok, map()} | {:error, term()}

  @doc "Start the transport connection"
  @callback start_link(keyword()) :: {:ok, pid()} | {:error, term()}

  @doc "Send a message to Playwright and wait for response"
  @callback send_message(transport(), message(), timeout()) :: result()

  @doc "Launch a browser instance"
  @callback launch_browser(transport(), browser_type(), keyword()) ::
              {:ok, guid()} | {:error, term()}

  @doc "Create a new browser context"
  @callback new_context(transport(), guid(), keyword()) :: {:ok, guid()} | {:error, term()}

  @doc "Create a new page in a context"
  @callback new_page(transport(), guid()) :: {:ok, map()} | {:error, term()}

  @doc "Navigate to a URL"
  @callback goto(transport(), guid(), String.t(), keyword()) :: result()

  @doc "Get page content"
  @callback content(transport(), guid()) :: {:ok, String.t()} | {:error, term()}

  @doc "Take a screenshot"
  @callback screenshot(transport(), guid(), keyword()) :: {:ok, binary()} | {:error, term()}

  @doc "Click an element"
  @callback click(transport(), guid(), String.t(), keyword()) :: :ok | {:error, term()}

  @doc "Fill an input"
  @callback fill(transport(), guid(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}

  @doc """
  Evaluate a JavaScript expression in a frame and return the result.

  `opts` may include `:is_function` (treat the expression as a function body),
  `:arg` (an argument passed to the function), and `:timeout`.
  """
  @callback evaluate(transport(), guid(), String.t(), keyword()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Wait until a JavaScript predicate becomes truthy in a frame.

  `opts` may include `:is_function`, `:arg`, `:polling` (a number of ms or
  `"raf"`), and `:timeout`.
  """
  @callback wait_for_function(transport(), guid(), String.t(), keyword()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Add an init script to a context, evaluated before any page scripts on every
  page/navigation in that context. Targets a context guid, so it must be
  installed before the page is created.
  """
  @callback add_init_script(transport(), guid(), String.t(), keyword()) ::
              :ok | {:error, term()}

  @doc """
  Open a Chrome DevTools Protocol session for a page. Returns an opaque CDP
  session id to be used with `cdp_send/4`.

  Only the `:windows` transport supports CDP; `:local` returns
  `{:error, :not_supported}` (playwright_ex exposes no CDP surface).
  """
  @callback new_cdp_session(transport(), guid()) :: {:ok, guid()} | {:error, term()}

  @doc """
  Send a CDP command over a session opened with `new_cdp_session/2`
  (e.g. `Network.emulateNetworkConditions`). Windows transport only.
  """
  @callback cdp_send(transport(), guid(), String.t(), map()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Expose an Elixir callback to the page as a binding: the page can call
  `window.<name>(...args)` and the transport invokes the callback with the
  argument list, returning its result to the page.

  **Experimental** and `:windows`-only - it is the one verb that needs the
  bidirectional event channel. `:local`/`:remote` return
  `{:error, :not_supported}`. Most harness needs are met by polling with
  `evaluate/4` + `wait_for_function/4`; prefer those.
  """
  @callback expose_binding(transport(), guid(), String.t(), (list() -> term())) ::
              :ok | {:error, term()}

  @doc "Close a page"
  @callback close_page(transport(), guid()) :: :ok | {:error, term()}

  @doc "Close a context"
  @callback close_context(transport(), guid()) :: :ok | {:error, term()}

  @doc "Close a browser"
  @callback close_browser(transport(), guid()) :: :ok | {:error, term()}

  @doc "Check if transport is healthy"
  @callback healthy?(transport()) :: boolean()

  @doc "Stop the transport"
  @callback stop(transport()) :: :ok
end
