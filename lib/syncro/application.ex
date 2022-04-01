defmodule Syncro.Application do
  use Application
  require Logger

  alias Syncro.Provider

  def start(_type, _args) do
    Provider.create()

    opts = [strategy: :one_for_one, name: Syncro.Supervisor]
    Supervisor.start_link([], opts)
  end
end
