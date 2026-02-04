defmodule Playwriter.Transport.Remote do
  @moduledoc """
  Remote transport using WebSocket to connect to a Playwright server.

  This transport connects to a running Playwright server (e.g., on Windows)
  via WebSocket. Suitable for:
  - WSL-to-Windows browser visibility
  - Distributed browser automation
  - Remote browser control
  """

  @behaviour Playwriter.Transport.Behaviour

  use GenServer
  require Logger

  defstruct [
    :ws_endpoint,
    :ws_pid,
    :browser_guid,
    :pending_calls,
    :next_id,
    :status
  ]

  @type t :: %__MODULE__{
          ws_endpoint: String.t(),
          ws_pid: pid() | nil,
          browser_guid: String.t() | nil,
          pending_calls: map(),
          next_id: pos_integer(),
          status: :connecting | :connected | :disconnected
        }

  # Client API

  @impl Playwriter.Transport.Behaviour
  def start_link(opts \\ []) do
    case validate_opts(opts) do
      {:ok, validated_opts} ->
        GenServer.start_link(__MODULE__, validated_opts, name: opts[:name])

      {:error, _} = error ->
        error
    end
  end

  @impl Playwriter.Transport.Behaviour
  def send_message(transport, message, timeout \\ 30_000) do
    GenServer.call(transport, {:send_message, message, timeout}, timeout + 5_000)
  end

  @doc "Get the browser guid from the server"
  @spec get_browser(GenServer.server()) :: {:ok, String.t()} | {:error, term()}
  def get_browser(transport) do
    GenServer.call(transport, :get_browser)
  end

  @impl Playwriter.Transport.Behaviour
  def launch_browser(transport, _browser_type, _opts \\ []) do
    # Remote server already has a browser running
    get_browser(transport)
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
  def close_browser(transport, _browser_guid) do
    # Don't actually close the remote browser
    GenServer.call(transport, :noop)
    :ok
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
    ws_endpoint = opts[:ws_endpoint]
    timeout = opts[:timeout] || 30_000

    state = %__MODULE__{
      ws_endpoint: ws_endpoint,
      pending_calls: %{},
      next_id: 1,
      status: :connecting
    }

    case connect_websocket(ws_endpoint, timeout) do
      {:ok, ws_pid, browser_guid} ->
        {:ok, %{state | ws_pid: ws_pid, browser_guid: browser_guid, status: :connected}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call(:get_browser, _from, state) do
    {:reply, {:ok, state.browser_guid}, state}
  end

  @impl GenServer
  def handle_call({:new_context, browser_guid, opts}, from, state) do
    params = build_context_params(opts)
    {id, state} = send_ws_message(state, browser_guid, "newContext", params, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_call({:new_page, context_guid}, from, state) do
    {id, state} = send_ws_message(state, context_guid, "newPage", %{}, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_call({:goto, frame_guid, url, opts}, from, state) do
    params = %{
      "url" => url,
      "timeout" => opts[:timeout] || 30_000,
      "waitUntil" => to_string(opts[:wait_until] || :load)
    }

    {id, state} = send_ws_message(state, frame_guid, "goto", params, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_call({:content, frame_guid}, from, state) do
    {id, state} = send_ws_message(state, frame_guid, "content", %{}, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_call({:screenshot, page_guid, opts}, from, state) do
    params = %{
      "fullPage" => opts[:full_page] || false,
      "omitBackground" => opts[:omit_background] || false
    }

    {id, state} = send_ws_message(state, page_guid, "screenshot", params, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_call({:click, frame_guid, selector, opts}, from, state) do
    params = %{
      "selector" => selector,
      "timeout" => opts[:timeout] || 30_000
    }

    {id, state} = send_ws_message(state, frame_guid, "click", params, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_call({:fill, frame_guid, selector, value, opts}, from, state) do
    params = %{
      "selector" => selector,
      "value" => value,
      "timeout" => opts[:timeout] || 30_000
    }

    {id, state} = send_ws_message(state, frame_guid, "fill", params, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_call({:close_page, page_guid}, from, state) do
    {id, state} = send_ws_message(state, page_guid, "close", %{}, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_call({:close_context, context_guid}, from, state) do
    {id, state} = send_ws_message(state, context_guid, "close", %{}, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_call(:noop, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:healthy?, _from, state) do
    healthy = state.status == :connected and state.ws_pid != nil and Process.alive?(state.ws_pid)
    {:reply, healthy, state}
  end

  @impl GenServer
  def handle_call({:send_message, message, _timeout}, from, state) do
    guid = message[:guid] || message["guid"]
    method = message[:method] || message["method"]
    params = message[:params] || message["params"] || %{}

    {id, state} = send_ws_message(state, guid, to_string(method), params, from)
    {:noreply, state, {:continue, {:wait_response, id}}}
  end

  @impl GenServer
  def handle_continue({:wait_response, _id}, state) do
    # Response will come via handle_info from WebSocket
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:ws_message, data}, state) do
    case Jason.decode(data) do
      {:ok, %{"id" => id} = response} ->
        handle_response(state, id, response)

      {:ok, %{"method" => _method} = _event} ->
        # Handle events (subscriptions) if needed
        {:noreply, state}

      {:error, _} ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:ws_closed, _reason}, state) do
    {:noreply, %{state | status: :disconnected, ws_pid: nil}}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    if state.ws_pid && Process.alive?(state.ws_pid) do
      send(state.ws_pid, :close)
    end

    :ok
  end

  # Private functions

  defp validate_opts(opts) do
    case opts[:ws_endpoint] do
      nil ->
        {:error, {:missing_option, :ws_endpoint}}

      endpoint when is_binary(endpoint) ->
        case URI.parse(endpoint) do
          %URI{scheme: scheme, host: host} when scheme in ["ws", "wss"] and is_binary(host) ->
            {:ok, opts}

          _ ->
            {:error, {:invalid_endpoint, endpoint}}
        end

      _ ->
        {:error, {:invalid_endpoint, opts[:ws_endpoint]}}
    end
  end

  defp connect_websocket(ws_endpoint, timeout) do
    parent = self()

    # Start a simple WebSocket client
    ws_pid =
      spawn_link(fn ->
        websocket_loop(parent, ws_endpoint, timeout)
      end)

    # Wait for connection and browser guid
    receive do
      {:ws_connected, browser_guid} ->
        {:ok, ws_pid, browser_guid}

      {:ws_error, reason} ->
        {:error, reason}
    after
      timeout ->
        Process.exit(ws_pid, :kill)
        {:error, :timeout}
    end
  end

  defp websocket_loop(parent, ws_endpoint, timeout) do
    uri = URI.parse(ws_endpoint)
    host = to_charlist(uri.host)
    port = uri.port || 80

    case :gen_tcp.connect(host, port, [:binary, active: true], timeout) do
      {:ok, socket} ->
        # Send WebSocket upgrade request
        path = uri.path || "/"
        key = Base.encode64(:crypto.strong_rand_bytes(16))

        request =
          "GET #{path} HTTP/1.1\r\n" <>
            "Host: #{uri.host}:#{port}\r\n" <>
            "Upgrade: websocket\r\n" <>
            "Connection: Upgrade\r\n" <>
            "Sec-WebSocket-Key: #{key}\r\n" <>
            "Sec-WebSocket-Version: 13\r\n" <>
            "\r\n"

        :gen_tcp.send(socket, request)
        wait_for_upgrade(parent, socket)

      {:error, reason} ->
        send(parent, {:ws_error, reason})
    end
  end

  defp wait_for_upgrade(parent, socket) do
    receive do
      {:tcp, ^socket, data} ->
        if String.contains?(data, "101 Switching Protocols") do
          # WebSocket connected, now wait for browser info
          # The Playwright server sends initial messages with browser guid
          handle_websocket_messages(parent, socket, <<>>, nil)
        else
          send(parent, {:ws_error, :upgrade_failed})
        end

      {:tcp_closed, ^socket} ->
        send(parent, {:ws_error, :closed})

      {:tcp_error, ^socket, reason} ->
        send(parent, {:ws_error, reason})
    after
      10_000 ->
        send(parent, {:ws_error, :timeout})
    end
  end

  defp handle_websocket_messages(parent, socket, buffer, browser_guid) do
    receive do
      {:tcp, ^socket, data} ->
        buffer = buffer <> data
        {messages, buffer} = parse_websocket_frames(buffer)

        browser_guid =
          Enum.reduce(messages, browser_guid, fn msg, acc ->
            case Jason.decode(msg) do
              {:ok,
               %{"method" => "__create__", "params" => %{"type" => "Browser", "guid" => guid}}} ->
                guid

              {:ok, %{"method" => "__create__", "params" => %{"type" => "BrowserContext"}}} ->
                acc

              {:ok, parsed} ->
                send(parent, {:ws_message, Jason.encode!(parsed)})
                acc

              _ ->
                acc
            end
          end)

        if browser_guid && browser_guid != nil do
          send(parent, {:ws_connected, browser_guid})
        end

        handle_websocket_messages(parent, socket, buffer, browser_guid)

      {:tcp_closed, ^socket} ->
        send(parent, {:ws_closed, :normal})

      {:tcp_error, ^socket, reason} ->
        send(parent, {:ws_closed, reason})

      {:send, message} ->
        frame = encode_websocket_frame(message)
        :gen_tcp.send(socket, frame)
        handle_websocket_messages(parent, socket, buffer, browser_guid)

      :close ->
        :gen_tcp.close(socket)
    end
  end

  defp parse_websocket_frames(data) do
    parse_websocket_frames(data, [])
  end

  defp parse_websocket_frames(<<>>, messages) do
    {Enum.reverse(messages), <<>>}
  end

  defp parse_websocket_frames(
         <<_fin::1, _rsv::3, _opcode::4, 0::1, len::7, rest::binary>> = data,
         messages
       )
       when len < 126 do
    if byte_size(rest) >= len do
      <<payload::binary-size(len), remaining::binary>> = rest
      parse_websocket_frames(remaining, [payload | messages])
    else
      {Enum.reverse(messages), data}
    end
  end

  defp parse_websocket_frames(
         <<_fin::1, _rsv::3, _opcode::4, 0::1, 126::7, len::16, rest::binary>> = data,
         messages
       ) do
    if byte_size(rest) >= len do
      <<payload::binary-size(len), remaining::binary>> = rest
      parse_websocket_frames(remaining, [payload | messages])
    else
      {Enum.reverse(messages), data}
    end
  end

  defp parse_websocket_frames(data, messages) do
    {Enum.reverse(messages), data}
  end

  defp encode_websocket_frame(message) do
    payload = if is_binary(message), do: message, else: Jason.encode!(message)
    len = byte_size(payload)
    mask_key = :crypto.strong_rand_bytes(4)
    masked_payload = mask_payload(payload, mask_key)

    cond do
      len < 126 ->
        <<1::1, 0::3, 1::4, 1::1, len::7, mask_key::binary, masked_payload::binary>>

      len < 65_536 ->
        <<1::1, 0::3, 1::4, 1::1, 126::7, len::16, mask_key::binary, masked_payload::binary>>

      true ->
        <<1::1, 0::3, 1::4, 1::1, 127::7, len::64, mask_key::binary, masked_payload::binary>>
    end
  end

  defp mask_payload(payload, mask_key) do
    mask_bytes = :binary.bin_to_list(mask_key)

    payload
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.map(fn {byte, i} -> Bitwise.bxor(byte, Enum.at(mask_bytes, rem(i, 4))) end)
    |> :binary.list_to_bin()
  end

  defp send_ws_message(state, guid, method, params, from) do
    id = state.next_id

    message = %{
      "id" => id,
      "guid" => guid,
      "method" => method,
      "params" => params
    }

    send(state.ws_pid, {:send, message})

    pending_calls = Map.put(state.pending_calls, id, from)
    {id, %{state | pending_calls: pending_calls, next_id: id + 1}}
  end

  defp handle_response(state, id, response) do
    case Map.pop(state.pending_calls, id) do
      {nil, _} ->
        {:noreply, state}

      {from, pending_calls} ->
        result =
          case response do
            %{"error" => error} ->
              {:error, error}

            %{"result" => result} ->
              process_result(result)

            _ ->
              {:ok, response}
          end

        GenServer.reply(from, result)
        {:noreply, %{state | pending_calls: pending_calls}}
    end
  end

  defp process_result(%{"value" => value}), do: {:ok, value}
  defp process_result(%{"binary" => b64}), do: {:ok, Base.decode64!(b64)}
  defp process_result(%{"guid" => _} = result), do: {:ok, atomize_keys(result)}
  defp process_result(%{"context" => _} = result), do: {:ok, atomize_keys(result)}
  defp process_result(result) when is_map(result), do: {:ok, atomize_keys(result)}
  defp process_result(result), do: {:ok, result}

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(Macro.underscore(k)), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(other), do: other

  defp build_context_params(opts) do
    %{}
    |> maybe_put("viewport", opts[:viewport])
    |> maybe_put("userAgent", opts[:user_agent])
    |> maybe_put("locale", opts[:locale])
    |> maybe_put("colorScheme", opts[:color_scheme])
    |> maybe_put("extraHTTPHeaders", opts[:headers])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
