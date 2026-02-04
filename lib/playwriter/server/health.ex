defmodule Playwriter.Server.Health do
  @moduledoc """
  Health checking for Playwright server.
  """

  @doc """
  Check if a Playwright server is responding at the given endpoint.

  ## Options

  - `:timeout` - Connection timeout in ms (default: 5000)

  ## Examples

      :ok = Health.check("ws://localhost:3337/")
      {:error, :econnrefused} = Health.check("ws://localhost:9999/")
  """
  @spec check(String.t(), keyword()) :: :ok | {:error, term()}
  def check(ws_endpoint, opts \\ []) do
    timeout = opts[:timeout] || 5_000
    uri = URI.parse(ws_endpoint)
    host = to_charlist(uri.host || "localhost")
    port = uri.port || 80

    case :gen_tcp.connect(host, port, [:binary, active: false], timeout) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Wait for server to become available.

  Polls the endpoint until it responds or timeout is reached.

  ## Options

  - `:timeout` - Total timeout in ms (default: 30000)
  - `:interval` - Poll interval in ms (default: 500)

  ## Examples

      :ok = Health.wait_for("ws://localhost:3337/")
      {:error, :timeout} = Health.wait_for("ws://localhost:9999/", timeout: 1000)
  """
  @spec wait_for(String.t(), keyword()) :: :ok | {:error, :timeout}
  def wait_for(ws_endpoint, opts \\ []) do
    timeout = opts[:timeout] || 30_000
    interval = opts[:interval] || 500
    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait(ws_endpoint, interval, deadline)
  end

  defp do_wait(ws_endpoint, interval, deadline) do
    case check(ws_endpoint, timeout: min(interval, 1000)) do
      :ok ->
        :ok

      {:error, _} ->
        now = System.monotonic_time(:millisecond)

        if now >= deadline do
          {:error, :timeout}
        else
          Process.sleep(interval)
          do_wait(ws_endpoint, interval, deadline)
        end
    end
  end
end
