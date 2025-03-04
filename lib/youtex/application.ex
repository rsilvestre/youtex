defmodule Youtex.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Initialize cache configuration with the configured backends
    cache_config = Application.get_env(:youtex, :cache, [])

    children = [
      {Youtex.Cache, cache_config}
    ]

    opts = [strategy: :one_for_one, name: Youtex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
