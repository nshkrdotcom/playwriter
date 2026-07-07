defmodule Playwriter.Transport.WindowsCmd do
  @moduledoc """
  Windows command transport - executes Playwright via PowerShell/cmd.exe.

  This transport avoids WSL2 networking issues by running Node.js Playwright
  directly on Windows via PowerShell, communicating through stdin/stdout.

  ## Wire protocol

  Requests are newline-delimited JSON `{id, method, params}`; responses are
  `{id, result}` or `{id, error}`. Results carry an explicit envelope:

  - `{"json": v}` - an arbitrary evaluated value (`evaluate`, `cdp_send`)
  - `{"value_b64": b}` - base64 binary (`screenshot`), decoded to a binary
  - `{"value": s}` - a plain string (`content`)
  - `{"guid": g}` - an object handle (context/page/CDP session)
  - `{"ok": true}` - an action with no return value

  Unsolicited `{"event": "binding", ...}` messages (from `expose_binding/4`)
  are routed to the registered Elixir callback rather than dropped.
  """

  @behaviour Playwriter.Transport.Behaviour

  use GenServer
  require Logger

  defstruct [:port, :request_id, :pending, :browser_ready, buffer: "", bindings: %{}]

  @node_script """
  const { chromium } = require('playwright');
  const readline = require('readline');

  let browser = null;
  let contexts = {};
  let pages = {};
  let cdpSessions = {};
  let cdpSeq = 0;
  let pendingBindings = {};
  let bindingSeq = 0;

  function emit(obj) { console.log(JSON.stringify(obj)); }

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

        case 'newContext': {
          const ctx = await browser.newContext(cmd.params || {});
          const ctxId = 'ctx-' + Object.keys(contexts).length;
          contexts[ctxId] = ctx;
          result = { guid: ctxId };
          break;
        }

        case 'newPage': {
          const context = contexts[cmd.params.contextId] || await browser.newContext();
          if (!contexts[cmd.params.contextId]) contexts[cmd.params.contextId] = context;
          const page = await context.newPage();
          const pageId = 'page-' + Object.keys(pages).length;
          pages[pageId] = page;
          result = { guid: pageId, mainFrame: { guid: pageId } };
          break;
        }

        case 'goto':
          await pages[cmd.params.pageId].goto(cmd.params.url, { timeout: cmd.params.timeout || 30000 });
          result = { ok: true };
          break;

        case 'content':
          result = { value: await pages[cmd.params.pageId].content() };
          break;

        case 'evaluate': {
          const page = pages[cmd.params.pageId];
          const fn = cmd.params.isFunction ? eval('(' + cmd.params.expression + ')') : cmd.params.expression;
          const r = await page.evaluate(fn, cmd.params.arg);
          result = { json: r === undefined ? null : r };
          break;
        }

        case 'waitForFunction': {
          const page = pages[cmd.params.pageId];
          const fn = cmd.params.isFunction ? eval('(' + cmd.params.expression + ')') : cmd.params.expression;
          await page.waitForFunction(fn, cmd.params.arg, {
            timeout: cmd.params.timeout || 30000,
            polling: cmd.params.polling || 'raf'
          });
          result = { ok: true };
          break;
        }

        case 'addInitScript':
          await contexts[cmd.params.contextId].addInitScript({ content: cmd.params.script });
          result = { ok: true };
          break;

        case 'addCookies':
          await contexts[cmd.params.contextId].addCookies(cmd.params.cookies);
          result = { ok: true };
          break;

        case 'storageState': {
          const s = await contexts[cmd.params.contextId].storageState();
          result = { json: s };
          break;
        }

        case 'newCDPSession': {
          const page = pages[cmd.params.pageId];
          const session = await page.context().newCDPSession(page);
          const sid = 'cdp-' + (++cdpSeq);
          cdpSessions[sid] = session;
          result = { guid: sid };
          break;
        }

        case 'cdpSend': {
          const r = await cdpSessions[cmd.params.sessionId].send(cmd.params.cdpMethod, cmd.params.cdpParams || {});
          result = { json: r === undefined ? null : r };
          break;
        }

        case 'exposeBinding': {
          const ctx = contexts[cmd.params.contextId];
          const name = cmd.params.name;
          await ctx.exposeBinding(name, async (source, ...args) => {
            const callId = 'call-' + (++bindingSeq);
            const promise = new Promise((resolve) => { pendingBindings[callId] = resolve; });
            emit({ event: 'binding', name: name, callId: callId, args: args });
            return await promise;
          });
          result = { ok: true };
          break;
        }

        case 'bindingResult': {
          const resolve = pendingBindings[cmd.params.callId];
          if (resolve) { resolve(cmd.params.value); delete pendingBindings[cmd.params.callId]; }
          result = { ok: true };
          break;
        }

        case 'screenshot': {
          const buf = await pages[cmd.params.pageId].screenshot(cmd.params);
          result = { value_b64: buf.toString('base64') };
          break;
        }

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

      emit({ id: cmd.id, result });
    } catch (err) {
      emit({ id: cmd?.id || 0, error: err.message });
    }
  }

  rl.on('line', handleCommand);
  rl.on('close', () => process.exit(0));

  emit({ ready: true });
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
  def new_cdp_session(transport, page_guid) do
    GenServer.call(transport, {:new_cdp_session, page_guid}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def cdp_send(transport, session_id, method, params) do
    GenServer.call(transport, {:cdp_send, session_id, method, params}, 35_000)
  end

  @impl Playwriter.Transport.Behaviour
  def expose_binding(transport, context_guid, name, callback) do
    GenServer.call(transport, {:expose_binding, context_guid, name, callback}, 35_000)
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

  defp call_timeout(opts), do: (opts[:timeout] || 30_000) + 5_000

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
  def handle_call({:evaluate, page_id, expression, opts}, from, state) do
    send_command(
      state,
      "evaluate",
      %{
        pageId: page_id,
        expression: expression,
        isFunction: opts[:is_function] || false,
        arg: opts[:arg]
      },
      from
    )
  end

  @impl GenServer
  def handle_call({:wait_for_function, page_id, expression, opts}, from, state) do
    send_command(
      state,
      "waitForFunction",
      %{
        pageId: page_id,
        expression: expression,
        isFunction: opts[:is_function] || false,
        arg: opts[:arg],
        timeout: opts[:timeout],
        polling: opts[:polling]
      },
      from
    )
  end

  @impl GenServer
  def handle_call({:add_init_script, context_id, script, _opts}, from, state) do
    send_command(state, "addInitScript", %{contextId: context_id, script: script}, from)
  end

  @impl GenServer
  def handle_call({:add_cookies, context_id, cookies}, from, state) do
    send_command(state, "addCookies", %{contextId: context_id, cookies: cookies}, from)
  end

  @impl GenServer
  def handle_call({:storage_state, context_id}, from, state) do
    send_command(state, "storageState", %{contextId: context_id}, from)
  end

  @impl GenServer
  def handle_call({:new_cdp_session, page_id}, from, state) do
    send_command(state, "newCDPSession", %{pageId: page_id}, from)
  end

  @impl GenServer
  def handle_call({:cdp_send, session_id, method, params}, from, state) do
    send_command(
      state,
      "cdpSend",
      %{sessionId: session_id, cdpMethod: method, cdpParams: params},
      from
    )
  end

  @impl GenServer
  def handle_call({:expose_binding, context_id, name, callback}, from, state) do
    state = %{state | bindings: Map.put(state.bindings, name, callback)}
    send_command(state, "exposeBinding", %{contextId: context_id, name: name}, from)
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
  def handle_cast({:binding_result, call_id, value}, state) do
    {:noreply, send_command_noreply(state, "bindingResult", %{callId: call_id, value: value})}
  end

  @impl GenServer
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    {messages, buffer} = split_messages(state.buffer, data)
    new_state = Enum.reduce(messages, %{state | buffer: buffer}, &route_message/2)
    {:noreply, new_state}
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
    Port.command(state.port, encode_command(id, method, params) <> "\n")
    pending = Map.put(state.pending, id, from)
    {:noreply, %{state | request_id: id + 1, pending: pending}}
  end

  # Fire-and-forget command (no caller awaits the reply), used to answer a
  # page->Elixir binding call. Its {ok:true} response has no pending entry and
  # is ignored by the router.
  defp send_command_noreply(state, method, params) do
    id = state.request_id
    Port.command(state.port, encode_command(id, method, params) <> "\n")
    %{state | request_id: id + 1}
  end

  defp route_message(msg, state) do
    case classify_message(msg) do
      {:response, id, result} -> reply_pending(state, id, process_result(result))
      {:error_response, id, error} -> reply_pending(state, id, {:error, error})
      {:binding, name, call_id, args} -> dispatch_binding(state, name, call_id, args)
      :ignore -> state
    end
  end

  defp reply_pending(state, id, reply) do
    case Map.pop(state.pending, id) do
      {nil, _} ->
        state

      {from, pending} ->
        GenServer.reply(from, reply)
        %{state | pending: pending}
    end
  end

  defp dispatch_binding(state, name, call_id, args) do
    case Map.get(state.bindings, name) do
      nil ->
        Logger.warning("Received binding event for unregistered binding: #{inspect(name)}")
        state

      callback ->
        transport = self()

        Task.start(fn ->
          value = callback.(args)
          GenServer.cast(transport, {:binding_result, call_id, value})
        end)

        state
    end
  end

  @doc false
  # Encode an outbound command to a JSON line (no trailing newline).
  def encode_command(id, method, params) do
    Jason.encode!(%{id: id, method: method, params: params})
  end

  @doc false
  # Split a byte-stream chunk (prepended with any buffered partial line) into
  # complete decoded JSON messages plus the remaining partial line. Stray
  # non-JSON stdout lines are dropped.
  def split_messages(buffer, data) do
    parts = String.split(buffer <> data, "\n")
    {complete, [partial]} = Enum.split(parts, -1)

    messages =
      complete
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&decode_line/1)
      |> Enum.reject(&is_nil/1)

    {messages, partial}
  end

  defp decode_line(line) do
    case Jason.decode(line) do
      {:ok, msg} -> msg
      {:error, _} -> nil
    end
  end

  @doc false
  # Classify a decoded protocol message into a routing action.
  def classify_message(%{"id" => id, "result" => result}), do: {:response, id, result}
  def classify_message(%{"id" => id, "error" => error}), do: {:error_response, id, error}

  def classify_message(%{"event" => "binding", "name" => name, "callId" => call_id} = msg),
    do: {:binding, name, call_id, Map.get(msg, "args", [])}

  def classify_message(_), do: :ignore

  @doc false
  # Map a result envelope to the transport's public return shape.
  def process_result(%{"guid" => guid} = result) do
    {:ok, (Map.get(result, "mainFrame") && %{guid: guid, main_frame: %{guid: guid}}) || guid}
  end

  def process_result(%{"json" => value}), do: {:ok, value}
  def process_result(%{"value_b64" => b64}), do: {:ok, Base.decode64!(b64)}
  def process_result(%{"value" => value}), do: {:ok, value}
  def process_result(%{"ok" => true}), do: :ok
  def process_result(result), do: {:ok, result}

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
        ~s|{"name":"playwriter-server","private":true,"dependencies":{"playwright":"^1.49.0"}}|

      File.write!(package_json_path, package_json)
      Logger.info("Created package.json, you may need to run: cd #{script_dir} && npm install")
    end

    script_path = Path.join(script_dir, "transport.js")
    File.write!(script_path, @node_script)

    Logger.debug("Wrote transport script to: #{script_path}")

    {script_dir, "transport.js"}
  end

  @doc false
  # Resolve the Windows account whose %TEMP% hosts the transport script.
  # Order:
  #   1. `config :playwriter, :windows_user` - explicit override.
  #   2. PowerShell `$env:USERNAME` - authoritative for the live session.
  #      (cmd.exe `echo %USERNAME%` returns garbage from WSL due to UNC
  #      path handling; PowerShell does not.)
  #   3. First plausible `/mnt/c/Users/` entry - the original heuristic,
  #      kept as a last resort. It picks the WRONG account on machines
  #      with more than one real user dir (e.g. a sandbox account that
  #      sorts first), which is why 1 and 2 exist.
  def get_windows_user do
    Application.get_env(:playwriter, :windows_user) ||
      powershell_username() ||
      users_dir_heuristic()
  end

  defp powershell_username do
    case System.cmd(
           find_powershell_exe(),
           ["-NoProfile", "-NonInteractive", "-Command", "$env:USERNAME"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        name = output |> String.replace("\r", "") |> String.trim()
        if name != "" and File.dir?("/mnt/c/Users/#{name}"), do: name

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp users_dir_heuristic do
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

  @doc false
  # Exposed for tests + tooling (e.g. `node --check`): the embedded Node script.
  def node_script, do: @node_script
end
