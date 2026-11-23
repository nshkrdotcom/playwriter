defmodule Playwriter.Application do
  @moduledoc false
  use Application

  @impl Application
  def start(_type, _args) do
    Supervisor.start_link([Playwriter.LocalDriver],
      strategy: :one_for_one,
      name: Playwriter.Supervisor
    )
  end
end
