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

  defstruct [:supervisor, :browser_types, :status]

  @type t :: %__MODULE__{
          supervisor: pid() | nil,
          browser_types: map(),
          status: :starting | :ready | :error
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
        {:ok, %__MODULE__{supervisor: supervisor, browser_types: %{}, status: :ready}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:launch_browser, browser_type, opts}, _from, state) do
    browser_opts = build_browser_opts(opts)

    case PlaywrightEx.launch_browser(browser_type, browser_opts) do
      {:ok, %{guid: guid}} ->
        {:reply, {:ok, guid}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:new_context, browser_guid, opts}, _from, state) do
    context_opts = build_context_opts(opts)

    case PlaywrightEx.Browser.new_context(browser_guid, context_opts) do
      {:ok, %{guid: context_guid}} ->
        {:reply, {:ok, context_guid}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:new_page, context_guid}, _from, state) do
    case PlaywrightEx.BrowserContext.new_page(context_guid, timeout: 30_000) do
      {:ok, %{guid: page_guid, main_frame: frame}} ->
        {:reply, {:ok, %{guid: page_guid, main_frame: frame}}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:goto, frame_guid, url, opts}, _from, state) do
    # playwright_ex >= 0.5 validates :wait_until as a string
    # ("load"/"domcontentloaded"/"networkidle"/"commit"), so normalise here to
    # accept either an atom or a string from callers.
    goto_opts =
      [
        url: url,
        timeout: opts[:timeout] || 30_000,
        wait_until: to_string(opts[:wait_until] || :load)
      ]

    case PlaywrightEx.Frame.goto(frame_guid, goto_opts) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:content, frame_guid}, _from, state) do
    case PlaywrightEx.Frame.content(frame_guid, timeout: 30_000) do
      {:ok, html} when is_binary(html) ->
        {:reply, {:ok, html}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:screenshot, page_guid, opts}, _from, state) do
    screenshot_opts = [
      timeout: opts[:timeout] || 30_000,
      full_page: opts[:full_page] || false,
      omit_background: opts[:omit_background] || false
    ]

    case PlaywrightEx.Page.screenshot(page_guid, screenshot_opts) do
      {:ok, base64_data} when is_binary(base64_data) ->
        # Playwright returns screenshot as base64-encoded data
        {:reply, {:ok, Base.decode64!(base64_data)}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:click, frame_guid, selector, opts}, _from, state) do
    click_opts = [selector: selector, timeout: opts[:timeout] || 30_000]

    case PlaywrightEx.Frame.click(frame_guid, click_opts) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:fill, frame_guid, selector, value, opts}, _from, state) do
    fill_opts = [selector: selector, value: value, timeout: opts[:timeout] || 30_000]

    case PlaywrightEx.Frame.fill(frame_guid, fill_opts) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:evaluate, frame_guid, expression, opts}, _from, state) do
    eval_opts =
      [expression: expression, timeout: opts[:timeout] || 30_000]
      |> maybe_add(:is_function, opts[:is_function])
      |> maybe_add(:arg, opts[:arg])

    {:reply, PlaywrightEx.Frame.evaluate(frame_guid, eval_opts), state}
  end

  @impl GenServer
  def handle_call({:wait_for_function, frame_guid, expression, opts}, _from, state) do
    wait_opts =
      [expression: expression, timeout: opts[:timeout] || 30_000]
      |> maybe_add(:is_function, opts[:is_function])
      |> maybe_add(:arg, opts[:arg])
      |> maybe_add(:polling, opts[:polling])

    case PlaywrightEx.Frame.wait_for_function(frame_guid, wait_opts) do
      {:ok, result} -> {:reply, {:ok, result}, state}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:add_init_script, context_guid, script, opts}, _from, state) do
    init_opts = [source: script, timeout: opts[:timeout] || 30_000]

    case PlaywrightEx.BrowserContext.add_init_script(context_guid, init_opts) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:add_cookies, context_guid, cookies}, _from, state) do
    case PlaywrightEx.BrowserContext.add_cookies(context_guid, cookies: cookies, timeout: 30_000) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:storage_state, context_guid}, _from, state) do
    {:reply, PlaywrightEx.BrowserContext.storage_state(context_guid, timeout: 30_000), state}
  end

  @impl GenServer
  def handle_call({:close_page, page_guid}, _from, state) do
    # Pages don't have a close method in playwright_ex directly
    # We send the close message (playwright_ex >= 0.5 takes opts, not a bare timeout)
    PlaywrightEx.send(%{guid: page_guid, method: :close}, timeout: 5_000)
    {:reply, :ok, state}
  catch
    _, _ -> {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:close_context, context_guid}, _from, state) do
    PlaywrightEx.BrowserContext.close(context_guid, timeout: 5_000)
    {:reply, :ok, state}
  catch
    _, _ -> {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:close_browser, browser_guid}, _from, state) do
    PlaywrightEx.Browser.close(browser_guid, timeout: 5_000)
    {:reply, :ok, state}
  catch
    _, _ -> {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:send_message, message, timeout}, _from, state) do
    result = PlaywrightEx.send(message, timeout: timeout)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:healthy?, _from, state) do
    healthy = state.status == :ready and Process.alive?(state.supervisor)
    {:reply, healthy, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    if state.supervisor && Process.alive?(state.supervisor) do
      Supervisor.stop(state.supervisor, :normal, 5_000)
    end

    :ok
  catch
    :exit, _ -> :ok
  end

  # Private functions

  defp start_playwright(opts) do
    playwright_opts =
      opts
      |> Keyword.take([:timeout, :executable])
      |> Keyword.put_new(:timeout, 30_000)
      |> Keyword.put_new(:executable, default_executable())

    PlaywrightEx.Supervisor.start_link(playwright_opts)
  end

  defp default_executable do
    # The :local transport shells out to a Node Playwright driver (cli.js).
    # Resolution order (first match wins), so the driver is provisioned
    # reproducibly rather than pinned to a hex artifact:
    #   1. PLAYWRIGHT_CLI env var (explicit override, e.g. CI)
    #   2. config :playwriter, :playwright_cli
    #   3. node_modules/playwright/cli.js under the current project
    #      (installed by `mix playwriter.setup`, pinned in package.json)
    #   4. the legacy hex `playwright` package location, if still present
    System.get_env("PLAYWRIGHT_CLI") ||
      Application.get_env(:playwriter, :playwright_cli) ||
      resolve_bundled_cli()
  end

  defp resolve_bundled_cli do
    candidates = [
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
    base = [timeout: opts[:timeout] || 30_000]

    base
    |> maybe_add(:viewport, opts[:viewport])
    |> maybe_add(:user_agent, opts[:user_agent])
    |> maybe_add(:locale, opts[:locale])
    |> maybe_add(:color_scheme, opts[:color_scheme])
    |> maybe_add(:extra_http_headers, opts[:headers])
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)
end
