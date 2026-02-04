defmodule Playwriter.Browser.Session do
  @moduledoc """
  Manages a browser session lifecycle.

  A session owns:
  - A transport connection
  - A browser instance
  - Multiple browser contexts
  - Pages within those contexts

  ## Example

      {:ok, session} = Session.start_link(mode: :local, headless: true)
      {:ok, page} = Session.new_page(session)
      :ok = Session.goto(session, page, "https://example.com")
      {:ok, html} = Session.content(session, page)
      :ok = Session.close(session)
  """

  use GenServer
  require Logger

  alias Playwriter.Transport
  alias Playwriter.Transport.{Local, Remote, WindowsCmd}

  @type page_info :: %{
          page_guid: String.t(),
          frame_guid: String.t(),
          context_guid: String.t()
        }

  defstruct [
    :transport,
    :transport_module,
    :browser_guid,
    :default_context_guid,
    pages: %{},
    contexts: %{},
    opts: []
  ]

  # Client API

  @doc """
  Start a new browser session.

  ## Options

  - `:mode` - `:local`, `:remote`, or `:auto` (default: `:auto`)
  - `:ws_endpoint` - WebSocket URL for remote mode
  - `:headless` - Run browser in headless mode (default: true)
  - `:browser_type` - `:chromium`, `:firefox`, or `:webkit` (default: `:chromium`)
  - `:name` - Optional name for the GenServer
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
  Create a new page in the default context.

  Returns a page_id that can be used with other Session functions.
  """
  @spec new_page(GenServer.server(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def new_page(session, opts \\ []) do
    GenServer.call(session, {:new_page, opts}, 60_000)
  end

  @doc """
  Create a new browser context.

  ## Options

  - `:viewport` - Viewport dimensions `%{width: 1920, height: 1080}`
  - `:user_agent` - Custom user agent string
  - `:locale` - User locale (e.g., "en-US")
  - `:color_scheme` - Color scheme preference (:light, :dark)
  """
  @spec new_context(GenServer.server(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def new_context(session, opts \\ []) do
    GenServer.call(session, {:new_context, opts}, 35_000)
  end

  @doc """
  Navigate to a URL.

  ## Options

  - `:timeout` - Navigation timeout in ms (default: 30000)
  - `:wait_until` - When to consider navigation complete (:load, :domcontentloaded, :networkidle)
  """
  @spec goto(GenServer.server(), String.t(), String.t(), keyword()) ::
          :ok | {:error, term()}
  def goto(session, page_id, url, opts \\ []) do
    GenServer.call(session, {:goto, page_id, url, opts}, 60_000)
  end

  @doc """
  Get page HTML content.
  """
  @spec content(GenServer.server(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def content(session, page_id) do
    GenServer.call(session, {:content, page_id}, 35_000)
  end

  @doc """
  Take a screenshot.

  ## Options

  - `:full_page` - Capture full scrollable page (default: false)
  - `:omit_background` - Omit background for transparent screenshots (default: false)
  """
  @spec screenshot(GenServer.server(), String.t(), keyword()) ::
          {:ok, binary()} | {:error, term()}
  def screenshot(session, page_id, opts \\ []) do
    GenServer.call(session, {:screenshot, page_id, opts}, 35_000)
  end

  @doc """
  Click an element.

  ## Options

  - `:timeout` - Click timeout in ms (default: 30000)
  """
  @spec click(GenServer.server(), String.t(), String.t(), keyword()) ::
          :ok | {:error, term()}
  def click(session, page_id, selector, opts \\ []) do
    GenServer.call(session, {:click, page_id, selector, opts}, 35_000)
  end

  @doc """
  Fill an input field.

  ## Options

  - `:timeout` - Fill timeout in ms (default: 30000)
  """
  @spec fill(GenServer.server(), String.t(), String.t(), String.t(), keyword()) ::
          :ok | {:error, term()}
  def fill(session, page_id, selector, value, opts \\ []) do
    GenServer.call(session, {:fill, page_id, selector, value, opts}, 35_000)
  end

  @doc """
  Close a page.
  """
  @spec close_page(GenServer.server(), String.t()) :: :ok | {:error, term()}
  def close_page(session, page_id) do
    GenServer.call(session, {:close_page, page_id}, 10_000)
  end

  @doc """
  Close the entire session.
  """
  @spec close(GenServer.server()) :: :ok
  def close(session) do
    GenServer.stop(session, :normal)
  catch
    :exit, _ -> :ok
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    case start_session(opts) do
      {:ok, state} ->
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:new_page, opts}, _from, state) do
    case create_page(state, opts) do
      {:ok, page_id, new_state} ->
        {:reply, {:ok, page_id}, new_state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:new_context, opts}, _from, state) do
    case create_context(state, opts) do
      {:ok, context_guid, new_state} ->
        {:reply, {:ok, context_guid}, new_state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:goto, page_id, url, opts}, _from, state) do
    case get_page_info(state, page_id) do
      {:ok, %{frame_guid: frame_guid}} ->
        result = call_transport(state, :goto, [frame_guid, url, opts])

        case result do
          {:ok, _} -> {:reply, :ok, state}
          error -> {:reply, error, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:content, page_id}, _from, state) do
    case get_page_info(state, page_id) do
      {:ok, %{frame_guid: frame_guid}} ->
        result = call_transport(state, :content, [frame_guid])
        {:reply, result, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:screenshot, page_id, opts}, _from, state) do
    case get_page_info(state, page_id) do
      {:ok, %{page_guid: page_guid}} ->
        result = call_transport(state, :screenshot, [page_guid, opts])
        {:reply, result, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:click, page_id, selector, opts}, _from, state) do
    case get_page_info(state, page_id) do
      {:ok, %{frame_guid: frame_guid}} ->
        result = call_transport(state, :click, [frame_guid, selector, opts])
        {:reply, result, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:fill, page_id, selector, value, opts}, _from, state) do
    case get_page_info(state, page_id) do
      {:ok, %{frame_guid: frame_guid}} ->
        result = call_transport(state, :fill, [frame_guid, selector, value, opts])
        {:reply, result, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:close_page, page_id}, _from, state) do
    case Map.pop(state.pages, page_id) do
      {nil, _} ->
        {:reply, {:error, :not_found}, state}

      {%{page_guid: page_guid}, pages} ->
        call_transport(state, :close_page, [page_guid])
        {:reply, :ok, %{state | pages: pages}}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    cleanup(state)
  end

  # Private functions

  defp start_session(opts) do
    mode = determine_mode(opts)
    transport_module = transport_module_for(mode)

    with {:ok, transport} <- start_transport(mode, opts),
         {:ok, browser_guid} <- launch_or_get_browser(transport, transport_module, opts) do
      {:ok,
       %__MODULE__{
         transport: transport,
         transport_module: transport_module,
         browser_guid: browser_guid,
         opts: opts
       }}
    end
  end

  defp determine_mode(opts) do
    cond do
      opts[:mode] == :windows -> :windows
      opts[:mode] == :remote -> :remote
      opts[:mode] == :local -> :local
      opts[:ws_endpoint] -> :remote
      true -> :local
    end
  end

  defp transport_module_for(:local), do: Local
  defp transport_module_for(:remote), do: Remote
  defp transport_module_for(:windows), do: WindowsCmd

  defp start_transport(:local, opts) do
    Local.start_link(opts)
  end

  defp start_transport(:remote, opts) do
    endpoint = opts[:ws_endpoint] || discover_endpoint(opts)

    case endpoint do
      nil -> {:error, :no_endpoint}
      ep -> Remote.start_link(Keyword.put(opts, :ws_endpoint, ep))
    end
  end

  defp start_transport(:windows, opts) do
    WindowsCmd.start_link(opts)
  end

  defp discover_endpoint(opts) do
    alias Playwriter.Server.Discovery

    case Discovery.discover(opts) do
      {:ok, endpoint} -> endpoint
      _ -> nil
    end
  end

  defp launch_or_get_browser(transport, Local, opts) do
    browser_type = opts[:browser_type] || :chromium
    browser_opts = Keyword.take(opts, [:headless, :slow_mo, :executable_path])
    Local.launch_browser(transport, browser_type, browser_opts)
  end

  defp launch_or_get_browser(_transport, Remote, _opts) do
    # Remote transport is not supported - will never reach here since start_link fails
    {:error, :not_supported}
  end

  defp launch_or_get_browser(transport, WindowsCmd, opts) do
    browser_opts = Keyword.take(opts, [:headless])
    WindowsCmd.launch_browser(transport, :chromium, browser_opts)
  end

  defp create_context(state, opts) do
    result = call_transport(state, :new_context, [state.browser_guid, opts])

    case result do
      {:ok, context_guid} ->
        contexts = Map.put(state.contexts, context_guid, %{pages: []})
        {:ok, context_guid, %{state | contexts: contexts}}

      error ->
        error
    end
  end

  defp create_page(state, opts) do
    context_guid = opts[:context_guid] || ensure_default_context(state)

    case context_guid do
      {:ok, ctx_guid, new_state} ->
        do_create_page(new_state, ctx_guid)

      ctx_guid when is_binary(ctx_guid) ->
        do_create_page(state, ctx_guid)

      error ->
        error
    end
  end

  defp ensure_default_context(%{default_context_guid: nil} = state) do
    case create_context(state, []) do
      {:ok, ctx_guid, new_state} ->
        {:ok, ctx_guid, %{new_state | default_context_guid: ctx_guid}}

      error ->
        error
    end
  end

  defp ensure_default_context(%{default_context_guid: ctx_guid}), do: ctx_guid

  defp do_create_page(state, context_guid) do
    result = call_transport(state, :new_page, [context_guid])

    case result do
      {:ok, %{guid: page_guid, main_frame: %{guid: frame_guid}}} ->
        page_id = generate_page_id()

        page_info = %{
          page_guid: page_guid,
          frame_guid: frame_guid,
          context_guid: context_guid
        }

        pages = Map.put(state.pages, page_id, page_info)
        {:ok, page_id, %{state | pages: pages}}

      error ->
        error
    end
  end

  defp get_page_info(state, page_id) do
    case Map.get(state.pages, page_id) do
      nil -> {:error, :not_found}
      info -> {:ok, info}
    end
  end

  defp call_transport(state, function, args) do
    apply(state.transport_module, function, [state.transport | args])
  end

  defp cleanup(state) do
    # Close all pages
    Enum.each(state.pages, fn {_id, %{page_guid: guid}} ->
      call_transport(state, :close_page, [guid])
    end)

    # Close all contexts
    Enum.each(state.contexts, fn {guid, _} ->
      call_transport(state, :close_context, [guid])
    end)

    # Close browser (local and windows modes)
    if state.transport_module in [Local, WindowsCmd] and state.browser_guid do
      call_transport(state, :close_browser, [state.browser_guid])
    end

    # Stop transport
    Transport.stop(state.transport)
  catch
    _, _ -> :ok
  end

  defp generate_page_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
