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
  require Logger

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
    GenServer.call(transport, {:new_context, browser_guid, opts})
  end

  @impl Playwriter.Transport.Behaviour
  def new_page(transport, context_guid) do
    GenServer.call(transport, {:new_page, context_guid})
  end

  @impl Playwriter.Transport.Behaviour
  def goto(transport, frame_guid, url, opts \\ []) do
    GenServer.call(transport, {:goto, frame_guid, url, opts}, 60_000)
  end

  @impl Playwriter.Transport.Behaviour
  def content(transport, frame_guid) do
    GenServer.call(transport, {:content, frame_guid})
  end

  @impl Playwriter.Transport.Behaviour
  def screenshot(transport, page_guid, opts \\ []) do
    GenServer.call(transport, {:screenshot, page_guid, opts})
  end

  @impl Playwriter.Transport.Behaviour
  def click(transport, frame_guid, selector, opts \\ []) do
    GenServer.call(transport, {:click, frame_guid, selector, opts})
  end

  @impl Playwriter.Transport.Behaviour
  def fill(transport, frame_guid, selector, value, opts \\ []) do
    GenServer.call(transport, {:fill, frame_guid, selector, value, opts})
  end

  @impl Playwriter.Transport.Behaviour
  def close_page(transport, page_guid) do
    GenServer.call(transport, {:close_page, page_guid})
  end

  @impl Playwriter.Transport.Behaviour
  def close_context(transport, context_guid) do
    GenServer.call(transport, {:close_context, context_guid})
  end

  @impl Playwriter.Transport.Behaviour
  def close_browser(transport, browser_guid) do
    GenServer.call(transport, {:close_browser, browser_guid})
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
    case PlaywrightEx.BrowserContext.new_page(context_guid, []) do
      {:ok, %{guid: page_guid, main_frame: frame}} ->
        {:reply, {:ok, %{guid: page_guid, main_frame: frame}}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:goto, frame_guid, url, opts}, _from, state) do
    goto_opts =
      [url: url, timeout: opts[:timeout] || 30_000, wait_until: opts[:wait_until] || :load]

    case PlaywrightEx.Frame.goto(frame_guid, goto_opts) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:content, frame_guid}, _from, state) do
    case PlaywrightEx.Frame.content(frame_guid, []) do
      {:ok, html} when is_binary(html) ->
        {:reply, {:ok, html}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:screenshot, page_guid, opts}, _from, state) do
    screenshot_opts = [
      full_page: opts[:full_page] || false,
      omit_background: opts[:omit_background] || false
    ]

    case PlaywrightEx.Page.screenshot(page_guid, screenshot_opts) do
      {:ok, binary} when is_binary(binary) ->
        {:reply, {:ok, binary}, state}

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
  def handle_call({:close_page, page_guid}, _from, state) do
    # Pages don't have a close method in playwright_ex directly
    # We send the close message
    PlaywrightEx.send(%{guid: page_guid, method: :close}, 5_000)
    {:reply, :ok, state}
  catch
    _, _ -> {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:close_context, context_guid}, _from, state) do
    PlaywrightEx.BrowserContext.close(context_guid, [])
    {:reply, :ok, state}
  catch
    _, _ -> {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:close_browser, browser_guid}, _from, state) do
    PlaywrightEx.Browser.close(browser_guid, [])
    {:reply, :ok, state}
  catch
    _, _ -> {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:send_message, message, timeout}, _from, state) do
    result = PlaywrightEx.send(message, timeout)
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
      Supervisor.stop(state.supervisor)
    end

    :ok
  end

  # Private functions

  defp start_playwright(opts) do
    playwright_opts =
      opts
      |> Keyword.take([:timeout, :executable])
      |> Keyword.put_new(:timeout, 30_000)

    PlaywrightEx.Supervisor.start_link(playwright_opts)
  end

  defp build_browser_opts(opts) do
    opts
    |> Keyword.take([:headless, :slow_mo, :executable_path, :channel])
    |> Keyword.put_new(:headless, true)
  end

  defp build_context_opts(opts) do
    base = []

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
