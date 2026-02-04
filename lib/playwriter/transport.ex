defmodule Playwriter.Transport do
  @moduledoc """
  Transport factory and utilities.

  Provides a unified interface for creating and working with transports.
  """

  alias Playwriter.Server.Discovery
  alias Playwriter.Transport.Local
  alias Playwriter.Transport.Remote

  @type mode :: :local | :remote | :auto
  @type transport :: pid()

  @doc """
  Start a transport based on configuration.

  ## Options

  - `:mode` - `:local`, `:remote`, or `:auto` (default: `:auto`)
  - `:ws_endpoint` - WebSocket URL for remote mode
  - `:headless` - boolean, only for local mode (default: true)
  - `:auto_discover` - attempt to find remote server in auto mode (default: true)
  - `:browser_type` - `:chromium`, `:firefox`, or `:webkit` (default: `:chromium`)

  ## Auto Mode

  In `:auto` mode, the transport will:
  1. Use `:remote` if `ws_endpoint` is provided
  2. Try to discover a Windows server if running in WSL and headless is false
  3. Fall back to `:local` mode

  ## Examples

      # Local headless browser
      {:ok, transport} = Playwriter.Transport.start(mode: :local, headless: true)

      # Connect to remote server
      {:ok, transport} = Playwriter.Transport.start(
        mode: :remote,
        ws_endpoint: "ws://localhost:3337/"
      )

      # Auto-detect best transport
      {:ok, transport} = Playwriter.Transport.start(mode: :auto)
  """
  @spec start(keyword()) :: {:ok, transport()} | {:error, term()}
  def start(opts \\ []) do
    mode = determine_mode(opts)

    case mode do
      :local -> Local.start_link(opts)
      :remote -> start_remote(opts)
    end
  end

  @doc """
  Stop a transport.
  """
  @spec stop(transport()) :: :ok
  def stop(transport) do
    if Process.alive?(transport) do
      GenServer.stop(transport, :normal)
    else
      :ok
    end
  catch
    :exit, _ -> :ok
  end

  @doc """
  Check if a transport is healthy.
  """
  @spec healthy?(transport()) :: boolean()
  def healthy?(transport) do
    cond do
      is_atom(transport) ->
        case Process.whereis(transport) do
          nil -> false
          pid -> healthy?(pid)
        end

      is_pid(transport) ->
        Process.alive?(transport) and
          GenServer.call(transport, :healthy?)

      true ->
        false
    end
  catch
    :exit, _ -> false
  end

  @doc """
  Determine if we're running in WSL.
  """
  @spec wsl?() :: boolean()
  def wsl? do
    case File.read("/proc/version") do
      {:ok, content} ->
        String.contains?(String.downcase(content), "microsoft")

      _ ->
        false
    end
  end

  # Private functions

  defp determine_mode(opts) do
    explicit_mode = opts[:mode]

    cond do
      explicit_mode in [:local, :remote] ->
        explicit_mode

      opts[:ws_endpoint] ->
        :remote

      explicit_mode == :auto or explicit_mode == nil ->
        auto_detect_mode(opts)

      true ->
        :local
    end
  end

  defp auto_detect_mode(opts) do
    # If headless is explicitly false and we're in WSL, try remote
    headless = Keyword.get(opts, :headless, true)
    auto_discover = Keyword.get(opts, :auto_discover, true)

    if wsl?() and not headless and auto_discover do
      case Discovery.discover(timeout: 1000) do
        {:ok, _endpoint} -> :remote
        _ -> :local
      end
    else
      :local
    end
  end

  defp start_remote(opts) do
    endpoint = opts[:ws_endpoint] || discover_endpoint(opts)

    case endpoint do
      nil ->
        {:error, :no_endpoint}

      endpoint ->
        Remote.start_link(Keyword.put(opts, :ws_endpoint, endpoint))
    end
  end

  defp discover_endpoint(opts) do
    case Discovery.discover(opts) do
      {:ok, endpoint} -> endpoint
      _ -> nil
    end
  end
end
