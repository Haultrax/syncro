defmodule Syncro.Application do
  use Application
  require Logger

  alias Syncro.{Nodes, Cache}

  @reconnect_period 10

  def start(_type, _args) do
    configure_nodes()

    children = [
      {Phoenix.PubSub, name: Syncro.server(), adapter: Phoenix.PubSub.PG2},
      Syncro.Cache,
      Syncro.Provider
    ]

    opts = [strategy: :one_for_one, name: Syncro.Supervisor]
    ret = Supervisor.start_link(children, opts)

    attach_listeners()

    ret
  end

  defp log(level, msg), do: Logger.log(level, "[Syncro] #{msg}")

  defp configure_nodes() do
    this_node = node()

    log(:info, "Node => #{this_node}")

    node_register = Application.get_env(:syncro, :nodes, %{})

    configure_liaison(this_node, node_register)

    Syncro.Nodes.configure(node_register)
  end

  defp configure_liaison(:nonode@nohost, _node_register), do: nil

  defp configure_liaison(_node, node_register) do
    log(:debug, "Configuring liaison")
    nodes = Map.values(node_register)

    strategy = [
      strategy: Liaison.Strategy.Epmd,
      nodes: nodes,
      reconnect_period: @reconnect_period
    ]

    Liaison.Application.add_child(strategy)
  end

  defp attach_listeners() do
    Application.get_env(:syncro, :listeners, %{})
    |> Enum.each(fn {name, node_designation} ->
      node = Nodes.designation_to_node(node_designation)
      Cache.listen_sync(name, node)
    end)
  end
end
