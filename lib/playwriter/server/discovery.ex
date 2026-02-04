defmodule Playwriter.Server.Discovery do
  @moduledoc """
  Discovers Playwright server endpoints in WSL-to-Windows scenarios.

  This module attempts to find a running Playwright server by trying
  various host/port combinations commonly used in WSL2 environments.
  """

  require Logger

  @default_ports [3337, 3336, 3335, 3334, 9222]
  @connection_timeout 1_000

  @doc """
  Discover a working WebSocket endpoint.

  Tries multiple host/port combinations to find a running Playwright server.

  ## Options

  - `:ports` - List of ports to try (default: #{inspect(@default_ports)})
  - `:timeout` - Connection timeout in ms (default: #{@connection_timeout})
  - `:hosts` - Override host list (default: auto-detected)

  ## Examples

      {:ok, "ws://localhost:3337/"} = Discovery.discover()
      {:error, :not_found} = Discovery.discover(ports: [9999])
  """
  @spec discover(keyword()) :: {:ok, String.t()} | {:error, :not_found}
  def discover(opts \\ []) do
    ports = opts[:ports] || @default_ports
    timeout = opts[:timeout] || @connection_timeout
    host_list = opts[:hosts] || hosts()

    endpoints =
      for host <- host_list, port <- ports do
        {host, port}
      end

    find_working_endpoint(endpoints, timeout)
  end

  @doc """
  Get list of candidate hosts.

  Returns hosts in order of preference:
  1. localhost
  2. 127.0.0.1
  3. WSL2 host IP (from /etc/resolv.conf)
  4. host.docker.internal
  """
  @spec hosts() :: [String.t()]
  def hosts do
    [
      "localhost",
      "127.0.0.1",
      get_wsl2_host_ip(),
      "host.docker.internal"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Get the Windows host IP from WSL2.

  Parses /etc/resolv.conf to find the nameserver, which in WSL2
  is typically the Windows host IP.
  """
  @spec get_wsl2_host_ip() :: String.t() | nil
  def get_wsl2_host_ip do
    case File.read("/etc/resolv.conf") do
      {:ok, content} ->
        case Regex.run(~r/nameserver\s+(\d+\.\d+\.\d+\.\d+)/, content) do
          [_, ip] -> ip
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Check if a specific endpoint is reachable.

  ## Examples

      :ok = Discovery.check_endpoint("ws://localhost:3337/")
      {:error, :econnrefused} = Discovery.check_endpoint("ws://localhost:9999/")
  """
  @spec check_endpoint(String.t(), keyword()) :: :ok | {:error, term()}
  def check_endpoint(endpoint, opts \\ []) do
    timeout = opts[:timeout] || @connection_timeout
    uri = URI.parse(endpoint)

    case :gen_tcp.connect(
           to_charlist(uri.host),
           uri.port || 80,
           [:binary, active: false],
           timeout
         ) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp find_working_endpoint([], _timeout) do
    {:error, :not_found}
  end

  defp find_working_endpoint([{host, port} | rest], timeout) do
    endpoint = "ws://#{host}:#{port}/"

    case check_endpoint(endpoint, timeout: timeout) do
      :ok ->
        Logger.debug("Found Playwright server at #{endpoint}")
        {:ok, endpoint}

      {:error, _reason} ->
        find_working_endpoint(rest, timeout)
    end
  end
end
