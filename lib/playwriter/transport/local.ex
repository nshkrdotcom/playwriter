defmodule Playwriter.Transport.Local do
  @moduledoc """
  Local transport using playwright_ex's port-based communication.

  This transport spawns a local Playwright Node.js driver and communicates
  via Erlang Ports through playwright_ex. Suitable for:
  - Headless automation
  - Headed automation on systems with display (Linux/macOS with GUI, Windows native)
  - CI/CD pipelines
  """

  @behaviour Playwriter.Transport.Behaviour

  use GenServer

  alias Playwright.{Browser, BrowserContext, BrowserType, Frame, Page}

  defstruct [:supervisor, :handles, :parents]

  @type t :: %__MODULE__{
          supervisor: pid() | nil,
          handles: %{String.t() => struct()},
          parents: %{String.t() => String.t()}
        }

  # Client API

  @impl Playwriter.Transport.Behaviour
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl Playwriter.Transport.Behaviour
  def send_message(transport, message, timeout \\ 30_000) do
    GenServer.call(transport, {:send_message, message, timeout}, timeout + 5_000)
  end

  @impl Playwriter.Transport.Behaviour
  def launch_browser(transport, browser_type, opts \\ []) do
    GenServer.call(transport, {:launch_browser, browser_type, opts}, 60_000)
  end

  @impl Playwriter.Transport.Behaviour
  def new_context(transport, browser_guid, opts \\ []) do
    GenServer.call(transport, {:new_context, browser_guid, opts}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def new_page(transport, context_guid) do
    GenServer.call(transport, {:new_page, context_guid}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def goto(transport, frame_guid, url, opts \\ []) do
    GenServer.call(transport, {:goto, frame_guid, url, opts}, 60_000)
  end

  @impl Playwriter.Transport.Behaviour
  def content(transport, frame_guid) do
    GenServer.call(transport, {:content, frame_guid}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def screenshot(transport, page_guid, opts \\ []) do
    GenServer.call(transport, {:screenshot, page_guid, opts}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def click(transport, frame_guid, selector, opts \\ []) do
    GenServer.call(transport, {:click, frame_guid, selector, opts}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def fill(transport, frame_guid, selector, value, opts \\ []) do
    GenServer.call(transport, {:fill, frame_guid, selector, value, opts}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def evaluate(transport, frame_guid, expression, opts \\ []) do
    GenServer.call(transport, {:evaluate, frame_guid, expression, opts}, call_timeout(opts))
  end

  @impl Playwriter.Transport.Behaviour
  def wait_for_function(transport, frame_guid, expression, opts \\ []) do
    GenServer.call(
      transport,
      {:wait_for_function, frame_guid, expression, opts},
      call_timeout(opts)
    )
  end

  @impl Playwriter.Transport.Behaviour
  def add_init_script(transport, context_guid, script, opts \\ []) do
    GenServer.call(transport, {:add_init_script, context_guid, script, opts}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def add_cookies(transport, context_guid, cookies) do
    GenServer.call(transport, {:add_cookies, context_guid, cookies}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def storage_state(transport, context_guid) do
    GenServer.call(transport, {:storage_state, context_guid}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def new_cdp_session(_transport, _page_guid) do
    # playwright_ex exposes no CDP surface; prefer server-side fault injection,
    # or the :windows transport for CDP-based faults.
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def cdp_send(_transport, _session_id, _method, _params) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def expose_binding(_transport, _context_guid, _name, _callback) do
    # Bindings need the bidirectional event channel the :windows transport adds.
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def close_page(transport, page_guid) do
    GenServer.call(transport, {:close_page, page_guid}, 10_000)
  end

  # Allow long-running predicates (wait_for_function) a generous GenServer
  # call timeout beyond the in-browser timeout.
  defp call_timeout(opts), do: (opts[:timeout] || 30_000) + 5_000

  @impl Playwriter.Transport.Behaviour
  def close_context(transport, context_guid) do
    GenServer.call(transport, {:close_context, context_guid}, 10_000)
  end

  @impl Playwriter.Transport.Behaviour
  def close_browser(transport, browser_guid) do
    GenServer.call(transport, {:close_browser, browser_guid}, 10_000)
  end

  @impl Playwriter.Transport.Behaviour
  def healthy?(transport) do
    GenServer.call(transport, :healthy?)
  catch
    :exit, _ -> false
  end

  @impl Playwriter.Transport.Behaviour
  def stop(transport) do
    GenServer.stop(transport, :normal)
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    case start_playwright(opts) do
      {:ok, supervisor} ->
        Process.monitor(supervisor)
        {:ok, %__MODULE__{supervisor: supervisor, handles: %{}, parents: %{}}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:launch_browser, browser_type, opts}, _from, state) do
    browser_opts = build_browser_opts(opts)

    case BrowserType.launch(browser_type(browser_type), browser_opts) do
      {:ok, browser} ->
        {:reply, {:ok, browser.guid}, put_handle(state, browser)}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:new_context, browser_guid, opts}, _from, state) do
    with {:ok, browser} <- fetch_handle(state, browser_guid),
         {:ok, context} <- Browser.new_context(browser, build_context_opts(opts)) do
      {:reply, {:ok, context.guid}, put_handle(state, context, browser_guid)}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:new_page, context_guid}, _from, state) do
    with {:ok, context} <- fetch_handle(state, context_guid),
         {:ok, page} <- BrowserContext.new_page(context) do
      frame = Page.main_frame(page)
      state = state |> put_handle(page, context_guid) |> put_handle(frame, page.guid)
      {:reply, {:ok, %{guid: page.guid, main_frame: %{guid: frame.guid}}}, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:goto, frame_guid, url, opts}, _from, state) do
    # Accept :wait_until as an atom or a string
    # ("load"/"domcontentloaded"/"networkidle"/"commit") from callers.
    goto_opts =
      [
        timeout: opts[:timeout] || 30_000,
        wait_until: wait_until(opts[:wait_until] || :load)
      ]

    with {:ok, frame} <- fetch_handle(state, frame_guid),
         {:ok, response} <- Frame.goto(frame, url, goto_opts) do
      {:reply, {:ok, response}, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:content, frame_guid}, _from, state) do
    with {:ok, frame} <- fetch_handle(state, frame_guid),
         {:ok, html} when is_binary(html) <- Frame.content(frame) do
      {:reply, {:ok, html}, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:screenshot, page_guid, opts}, _from, state) do
    screenshot_opts = [
      timeout: opts[:timeout] || 30_000,
      full_page: opts[:full_page] || false,
      omit_background: opts[:omit_background] || false
    ]

    with {:ok, page} <- fetch_handle(state, page_guid),
         {:ok, data} when is_binary(data) <- Page.screenshot(page, screenshot_opts) do
      {:reply, {:ok, data}, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:click, frame_guid, selector, opts}, _from, state) do
    with {:ok, frame} <- fetch_handle(state, frame_guid),
         :ok <- Frame.click(frame, selector, timeout: opts[:timeout] || 30_000) do
      {:reply, :ok, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:fill, frame_guid, selector, value, opts}, _from, state) do
    with {:ok, frame} <- fetch_handle(state, frame_guid),
         :ok <- Frame.fill(frame, selector, value, timeout: opts[:timeout] || 30_000) do
      {:reply, :ok, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:evaluate, frame_guid, expression, opts}, _from, state) do
    # The driver calls the expression when it evaluates to a function, so
    # :is_function needs no mapping.
    with {:ok, frame} <- fetch_handle(state, frame_guid),
         {:ok, result} <- Frame.evaluate(frame, expression, opts[:arg]) do
      {:reply, {:ok, null_to_nil(result)}, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:wait_for_function, frame_guid, expression, opts}, _from, state) do
    wait_opts =
      [timeout: opts[:timeout] || 30_000]
      |> maybe_add(:polling, polling(opts[:polling]))

    with {:ok, frame} <- fetch_handle(state, frame_guid),
         {:ok, handle} <- Frame.wait_for_function(frame, expression, opts[:arg], wait_opts) do
      result =
        try do
          with {:ok, value} <- Playwright.JSHandle.json_value(handle),
               do: {:ok, null_to_nil(value)}
        after
          Playwright.JSHandle.dispose(handle)
        end

      {:reply, result, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:add_init_script, context_guid, script, _opts}, _from, state) do
    with {:ok, context} <- fetch_handle(state, context_guid),
         {:ok, _} <- BrowserContext.add_init_script(context, script) do
      {:reply, :ok, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:add_cookies, context_guid, cookies}, _from, state) do
    with {:ok, context} <- fetch_handle(state, context_guid),
         :ok <- BrowserContext.add_cookies(context, cookies) do
      {:reply, :ok, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:storage_state, context_guid}, _from, state) do
    with {:ok, context} <- fetch_handle(state, context_guid),
         {:ok, storage_state} <- BrowserContext.storage_state(context) do
      # Same string-keyed shape as the :windows transport returns.
      {:reply, {:ok, storage_state |> Jason.encode!() |> Jason.decode!()}, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:close_page, page_guid}, _from, state) do
    {:reply, :ok, close_handle(state, page_guid, &Page.close/1)}
  end

  @impl GenServer
  def handle_call({:close_context, context_guid}, _from, state) do
    {:reply, :ok, close_handle(state, context_guid, &BrowserContext.close/1)}
  end

  @impl GenServer
  def handle_call({:close_browser, browser_guid}, _from, state) do
    {:reply, :ok, close_handle(state, browser_guid, &Browser.close/1)}
  end

  @impl GenServer
  def handle_call({:send_message, _message, _timeout}, _from, state) do
    # playwright_ex 1.x, like the Playwright JS client, exposes no raw protocol channel.
    {:reply, {:error, :not_supported}, state}
  end

  @impl GenServer
  def handle_call(:healthy?, _from, state) do
    {:reply, Process.alive?(state.supervisor), state}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, driver, reason}, %{supervisor: driver} = state) do
    {:stop, {:local_driver_exited, reason}, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    for %Browser{} = browser <- Map.values(state.handles), Process.alive?(state.supervisor) do
      safely_close(&Browser.close/1, browser)
    end

    :ok
  end

  # Private functions

  defp start_playwright(opts) do
    playwright_opts =
      opts
      |> Keyword.take([:executable])
      |> Keyword.put_new(:executable, default_executable())

    if File.regular?(playwright_opts[:executable]) and System.find_executable("node") do
      Playwriter.LocalDriver.acquire(Path.expand(playwright_opts[:executable]))
    else
      {:error, {:local_setup_required, "Run mix playwriter.setup in a shell with Node.js"}}
    end
  end

  defp browser_type(:chromium), do: Playwright.chromium(Playwriter.LocalDriver.instance())
  defp browser_type(:firefox), do: Playwright.firefox(Playwriter.LocalDriver.instance())
  defp browser_type(:webkit), do: Playwright.webkit(Playwriter.LocalDriver.instance())

  defp put_handle(state, handle), do: put_in(state.handles[handle.guid], handle)

  defp put_handle(state, handle, parent) do
    state = put_handle(state, handle)
    put_in(state.parents[handle.guid], parent)
  end

  defp close_handle(state, guid, close) do
    case Map.fetch(state.handles, guid) do
      {:ok, handle} ->
        safely_close(close, handle)
        guids = descendants(state.parents, guid)

        %{
          state
          | handles: Map.drop(state.handles, guids),
            parents: Map.drop(state.parents, guids)
        }

      :error ->
        state
    end
  end

  defp safely_close(close, handle) do
    close.(handle)
  catch
    _, _ -> :ok
  end

  defp descendants(parents, guid) do
    [
      guid
      | Enum.flat_map(parents, fn
          {child, ^guid} -> descendants(parents, child)
          _ -> []
        end)
    ]
  end

  defp fetch_handle(state, guid) do
    case Map.fetch(state.handles, guid) do
      {:ok, handle} -> {:ok, handle}
      :error -> {:error, {:unknown_guid, guid}}
    end
  end

  defp wait_until(value) when is_atom(value), do: value
  defp wait_until(value) when is_binary(value), do: String.to_existing_atom(value)

  defp polling("raf"), do: :raf
  defp polling(value), do: value

  # JS null comes back as :null; the transports return nil for it.
  defp null_to_nil(:null), do: nil
  defp null_to_nil(list) when is_list(list), do: Enum.map(list, &null_to_nil/1)

  defp null_to_nil(map) when is_map(map) and not is_struct(map),
    do: Map.new(map, fn {k, v} -> {k, null_to_nil(v)} end)

  defp null_to_nil(value), do: value

  defp default_executable do
    # Explicit overrides win, followed by the managed CLI and legacy locations.
    System.get_env("PLAYWRIGHT_CLI") ||
      Application.get_env(:playwriter, :playwright_cli) ||
      resolve_bundled_cli()
  end

  defp resolve_bundled_cli do
    candidates = [
      Playwriter.Setup.local_cli(),
      Path.join([File.cwd!(), "node_modules", "playwright", "cli.js"]),
      Path.join(["deps", "playwright", "priv", "static", "node_modules", "playwright", "cli.js"])
    ]

    Enum.find(candidates, List.first(candidates), &File.exists?/1)
  end

  defp build_browser_opts(opts) do
    opts
    |> Keyword.take([:headless, :slow_mo, :executable_path, :channel, :timeout])
    |> Keyword.put_new(:headless, true)
    |> Keyword.put_new(:timeout, 30_000)
  end

  defp build_context_opts(opts) do
    []
    |> maybe_add(:viewport, opts[:viewport])
    |> maybe_add(:user_agent, opts[:user_agent])
    |> maybe_add(:locale, opts[:locale])
    |> maybe_add(:color_scheme, opts[:color_scheme])
    |> maybe_add(:extra_http_headers, opts[:headers])
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)
end
