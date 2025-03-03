defmodule Youtex.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Youtex.Cache, []}
    ]

    opts = [strategy: :one_for_one, name: Youtex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
