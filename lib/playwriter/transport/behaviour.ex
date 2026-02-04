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
