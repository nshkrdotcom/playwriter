defmodule Playwriter.Transport.WindowsCmd do
  @moduledoc """
  Windows command transport - executes Playwright via PowerShell/cmd.exe.

  This transport avoids WSL2 networking issues by running Node.js Playwright
  directly on Windows via PowerShell, communicating through stdin/stdout.
  """

  @behaviour Playwriter.Transport.Behaviour

  use GenServer
  require Logger

  defstruct [:port, :request_id, :pending, :browser_ready]

  @node_script """
  const { chromium } = require('playwright');
  const readline = require('readline');

  let browser = null;
  let contexts = {};
  let pages = {};

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: false });

  async function handleCommand(line) {
    let cmd = null;
    try {
      cmd = JSON.parse(line);
      let result;

      switch (cmd.method) {
        case 'launch':
          browser = await chromium.launch({ headless: cmd.params?.headless ?? false });
          result = { guid: 'browser-1' };
          break;

        case 'newContext':
          const ctx = await browser.newContext(cmd.params || {});
          const ctxId = 'ctx-' + Object.keys(contexts).length;
          contexts[ctxId] = ctx;
          result = { guid: ctxId };
          break;

        case 'newPage':
          const context = contexts[cmd.params.contextId] || await browser.newContext();
          if (!contexts[cmd.params.contextId]) contexts[cmd.params.contextId] = context;
          const page = await context.newPage();
          const pageId = 'page-' + Object.keys(pages).length;
          pages[pageId] = page;
          result = { guid: pageId, mainFrame: { guid: pageId } };
          break;

        case 'goto':
          await pages[cmd.params.pageId].goto(cmd.params.url, { timeout: cmd.params.timeout || 30000 });
          result = { ok: true };
          break;

        case 'content':
          result = { value: await pages[cmd.params.pageId].content() };
          break;

        case 'screenshot':
          const buf = await pages[cmd.params.pageId].screenshot(cmd.params);
          result = { value: buf.toString('base64') };
          break;

        case 'click':
          await pages[cmd.params.pageId].click(cmd.params.selector, { timeout: cmd.params.timeout || 30000 });
          result = { ok: true };
          break;

        case 'fill':
          await pages[cmd.params.pageId].fill(cmd.params.selector, cmd.params.value, { timeout: cmd.params.timeout || 30000 });
          result = { ok: true };
          break;

        case 'closePage':
          if (pages[cmd.params.pageId]) { await pages[cmd.params.pageId].close(); delete pages[cmd.params.pageId]; }
          result = { ok: true };
          break;

        case 'closeContext':
          if (contexts[cmd.params.contextId]) { await contexts[cmd.params.contextId].close(); delete contexts[cmd.params.contextId]; }
          result = { ok: true };
          break;

        case 'close':
          if (browser) { await browser.close(); browser = null; }
          result = { ok: true };
          break;

        default:
          result = { error: 'Unknown method: ' + cmd.method };
      }

      console.log(JSON.stringify({ id: cmd.id, result }));
    } catch (err) {
      console.log(JSON.stringify({ id: cmd?.id || 0, error: err.message }));
    }
  }

  rl.on('line', handleCommand);
  rl.on('close', () => process.exit(0));

  console.log(JSON.stringify({ ready: true }));
  """

  # Client API

  @impl Playwriter.Transport.Behaviour
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl Playwriter.Transport.Behaviour
  def send_message(transport, message, timeout \\ 30_000) do
    GenServer.call(transport, {:send, message}, timeout)
  end

  @impl Playwriter.Transport.Behaviour
  def launch_browser(transport, _browser_type, opts \\ []) do
    GenServer.call(transport, {:launch, opts}, 60_000)
  end

  @impl Playwriter.Transport.Behaviour
  def new_context(transport, _browser_guid, opts \\ []) do
    GenServer.call(transport, {:new_context, opts}, 35_000)
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
  def close_page(transport, page_guid) do
    GenServer.call(transport, {:close_page, page_guid}, 10_000)
  end

  @impl Playwriter.Transport.Behaviour
  def close_context(transport, context_guid) do
    GenServer.call(transport, {:close_context, context_guid}, 10_000)
  end

  @impl Playwriter.Transport.Behaviour
  def close_browser(transport, _browser_guid) do
    GenServer.call(transport, :close_browser, 10_000)
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
  def init(_opts) do
    # Write the Node script to Windows temp
    {script_dir, script_name} = write_script_to_windows()

    # Build the Windows path for the script directory
    windows_user = get_windows_user()
    win_script_dir = "C:\\Users\\#{windows_user}\\AppData\\Local\\Temp\\playwriter-server"

    # Use PowerShell instead of cmd.exe - handles paths better from WSL
    # -NoProfile speeds up startup, -NonInteractive prevents prompts
    ps_cmd = "Set-Location '#{win_script_dir}'; node #{script_name}"

    Logger.debug("Starting PowerShell: #{ps_cmd}")
    Logger.debug("Script written to: #{script_dir}/#{script_name}")

    port =
      Port.open(
        {:spawn_executable, find_powershell_exe()},
        [
          :binary,
          :exit_status,
          :use_stdio,
          {:args, ["-NoProfile", "-NonInteractive", "-Command", ps_cmd]}
        ]
      )

    state = %__MODULE__{
      port: port,
      request_id: 1,
      pending: %{},
      browser_ready: false
    }

    # Wait for ready signal
    receive do
      {^port, {:data, data}} ->
        Logger.debug("Received from port: #{inspect(data)}")

        case Jason.decode(String.trim(data)) do
          {:ok, %{"ready" => true}} ->
            Logger.info("WindowsCmd transport ready")
            {:ok, %{state | browser_ready: true}}

          {:ok, other} ->
            Logger.error("Unexpected init response: #{inspect(other)}")
            {:stop, {:unexpected_response, other}}

          {:error, _} ->
            # Might be startup output, wait for more
            wait_for_ready(port, state, data)
        end
    after
      30_000 ->
        Logger.error("Timeout waiting for WindowsCmd transport to start")
        {:stop, :timeout}
    end
  end

  defp wait_for_ready(port, state, accumulated) do
    receive do
      {^port, {:data, data}} ->
        full_data = accumulated <> data
        # Try to find the ready message in accumulated data
        case Regex.run(~r/\{"ready":\s*true\}/, full_data) do
          [_match] ->
            Logger.info("WindowsCmd transport ready (after accumulation)")
            {:ok, %{state | browser_ready: true}}

          nil ->
            Logger.debug("Still waiting, got: #{inspect(data)}")
            wait_for_ready(port, state, full_data)
        end

      {^port, {:exit_status, code}} ->
        Logger.error("Port exited with code #{code}, output: #{accumulated}")
        {:stop, {:port_exit, code}}
    after
      25_000 ->
        Logger.error("Timeout in wait_for_ready, accumulated: #{accumulated}")
        {:stop, :timeout}
    end
  end

  @impl GenServer
  def handle_call({:launch, opts}, from, state) do
    send_command(state, "launch", %{headless: opts[:headless] || false}, from)
  end

  @impl GenServer
  def handle_call({:new_context, opts}, from, state) do
    send_command(state, "newContext", opts, from)
  end

  @impl GenServer
  def handle_call({:new_page, context_id}, from, state) do
    send_command(state, "newPage", %{contextId: context_id}, from)
  end

  @impl GenServer
  def handle_call({:goto, page_id, url, opts}, from, state) do
    send_command(state, "goto", %{pageId: page_id, url: url, timeout: opts[:timeout]}, from)
  end

  @impl GenServer
  def handle_call({:content, page_id}, from, state) do
    send_command(state, "content", %{pageId: page_id}, from)
  end

  @impl GenServer
  def handle_call({:screenshot, page_id, opts}, from, state) do
    send_command(state, "screenshot", Map.merge(%{pageId: page_id}, Map.new(opts)), from)
  end

  @impl GenServer
  def handle_call({:click, page_id, selector, opts}, from, state) do
    send_command(
      state,
      "click",
      %{pageId: page_id, selector: selector, timeout: opts[:timeout]},
      from
    )
  end

  @impl GenServer
  def handle_call({:fill, page_id, selector, value, opts}, from, state) do
    send_command(
      state,
      "fill",
      %{pageId: page_id, selector: selector, value: value, timeout: opts[:timeout]},
      from
    )
  end

  @impl GenServer
  def handle_call({:close_page, page_id}, from, state) do
    send_command(state, "closePage", %{pageId: page_id}, from)
  end

  @impl GenServer
  def handle_call({:close_context, context_id}, from, state) do
    send_command(state, "closeContext", %{contextId: context_id}, from)
  end

  @impl GenServer
  def handle_call(:close_browser, from, state) do
    send_command(state, "close", %{}, from)
  end

  @impl GenServer
  def handle_call(:healthy?, _from, state) do
    {:reply, state.browser_ready && Port.info(state.port) != nil, state}
  end

  @impl GenServer
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    case Jason.decode(String.trim(data)) do
      {:ok, %{"id" => id, "result" => result}} ->
        case Map.pop(state.pending, id) do
          {nil, _} ->
            {:noreply, state}

          {from, pending} ->
            reply = process_result(result)
            GenServer.reply(from, reply)
            {:noreply, %{state | pending: pending}}
        end

      {:ok, %{"id" => id, "error" => error}} ->
        case Map.pop(state.pending, id) do
          {nil, _} ->
            {:noreply, state}

          {from, pending} ->
            GenServer.reply(from, {:error, error})
            {:noreply, %{state | pending: pending}}
        end

      _ ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({port, {:exit_status, _}}, %{port: port} = state) do
    {:stop, :port_closed, state}
  end

  @impl GenServer
  def handle_info(_msg, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    if state.port && Port.info(state.port) do
      Port.close(state.port)
    end

    :ok
  end

  # Private helpers

  defp send_command(state, method, params, from) do
    id = state.request_id
    cmd = Jason.encode!(%{id: id, method: method, params: params})
    Port.command(state.port, cmd <> "\n")
    pending = Map.put(state.pending, id, from)
    {:noreply, %{state | request_id: id + 1, pending: pending}}
  end

  defp process_result(%{"guid" => guid} = result) do
    {:ok, (Map.get(result, "mainFrame") && %{guid: guid, main_frame: %{guid: guid}}) || guid}
  end

  defp process_result(%{"value" => value}) when is_binary(value) do
    # Could be base64 screenshot or HTML content
    if String.starts_with?(value, "iVBOR") or String.starts_with?(value, "/9j/") do
      {:ok, Base.decode64!(value)}
    else
      {:ok, value}
    end
  end

  defp process_result(%{"ok" => true}), do: :ok
  defp process_result(result), do: {:ok, result}

  defp write_script_to_windows do
    # Write to Windows temp via /mnt/c path
    windows_user = get_windows_user()
    script_dir = "/mnt/c/Users/#{windows_user}/AppData/Local/Temp/playwriter-server"

    Logger.debug("Creating script directory: #{script_dir}")
    File.mkdir_p!(script_dir)

    # Write package.json if missing
    package_json_path = Path.join(script_dir, "package.json")

    unless File.exists?(package_json_path) do
      package_json =
        ~s|{"name":"playwriter-server","private":true,"dependencies":{"playwright":"^1.40.0"}}|

      File.write!(package_json_path, package_json)
      Logger.info("Created package.json, you may need to run: cd #{script_dir} && npm install")
    end

    script_path = Path.join(script_dir, "transport.js")
    File.write!(script_path, @node_script)

    Logger.debug("Wrote transport script to: #{script_path}")

    {script_dir, "transport.js"}
  end

  defp get_windows_user do
    # Detect Windows user from /mnt/c/Users/ directory
    # cmd.exe echo %USERNAME% returns garbage from WSL due to UNC path handling
    case File.ls("/mnt/c/Users") do
      {:ok, entries} ->
        entries
        |> Enum.reject(&(&1 in ["Public", "Default", "Default User", "All Users", "desktop.ini"]))
        |> Enum.find(fn name ->
          path = "/mnt/c/Users/#{name}"
          File.dir?(path) and not String.starts_with?(name, ".")
        end) || "Default"

      _ ->
        "Default"
    end
  end

  defp find_powershell_exe do
    # Try PowerShell 7+ first, fall back to Windows PowerShell
    pwsh = "/mnt/c/Program Files/PowerShell/7/pwsh.exe"

    if File.exists?(pwsh) do
      pwsh
    else
      "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    end
  end
end
