defmodule Playwriter.LocalDriver do
  @moduledoc false
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def acquire(executable), do: GenServer.call(__MODULE__, {:acquire, executable}, 60_000)

  def instance, do: Playwright.instance(__MODULE__.Connection)

  @impl GenServer
  def init([]) do
    Process.flag(:trap_exit, true)
    {:ok, %{driver: nil, executable: nil, clients: %{}}}
  end

  @impl GenServer
  def handle_call({:acquire, executable}, {client, _}, %{driver: nil} = state) do
    case Playwright.Supervisor.start_link(name: __MODULE__.Connection, executable: executable) do
      {:ok, driver} ->
        {:reply, {:ok, driver},
         %{
           state
           | driver: driver,
             executable: executable,
             clients: %{Process.monitor(client) => client}
         }}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:acquire, executable}, {client, _}, %{executable: executable} = state) do
    {:reply, {:ok, state.driver}, put_in(state.clients[Process.monitor(client)], client)}
  end

  def handle_call({:acquire, _}, _from, state) do
    {:reply, {:error, :different_local_driver_in_use}, state}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _client, _reason}, state) do
    clients = Map.delete(state.clients, ref)

    if map_size(clients) == 0 and state.driver do
      stop_driver(state.driver)
      {:noreply, %{state | driver: nil, executable: nil, clients: clients}}
    else
      {:noreply, %{state | clients: clients}}
    end
  end

  def handle_info({:EXIT, driver, _reason}, %{driver: driver} = state) do
    Enum.each(Map.keys(state.clients), &Process.demonitor(&1, [:flush]))
    {:noreply, %{state | driver: nil, executable: nil, clients: %{}}}
  end

  def handle_info({:EXIT, _pid, _reason}, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, %{driver: driver}) when is_pid(driver), do: stop_driver(driver)
  def terminate(_reason, _state), do: :ok

  defp stop_driver(driver) do
    Supervisor.stop(driver, :normal, 5_000)
  catch
    :exit, _reason -> :ok
  end
end
