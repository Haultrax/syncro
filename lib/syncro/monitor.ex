defmodule Syncro.Monitor do
  require Logger
  use GenServer

  alias Syncro.{Nodes, Provider, Cache}

  defp log(level, msg), do: Logger.log(level, "[Syncro|Monitor] #{msg}")

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    :net_kernel.monitor_nodes(true)

    attach_listeners()
    Provider.sync_all()
    Cache.force_sync()

    {:ok, %{}}
  end

  def handle_info({:nodedown, _nodename}, state) do
    {:noreply, state}
  end

  def handle_info({:nodeup, nodename}, state) do
    if Provider.is_providing?() do
      log(:info, "Connected to #{nodename}")
      Provider.sync_all()
    end

    {:noreply, state}
  end

  def attach_listeners() do
    Application.get_env(:syncro, :listeners, %{})
    |> Enum.each(fn {name, node_designation} ->
      node = Nodes.designation_to_node(node_designation)
      Cache.listen_sync(name, node)
    end)
  end
end
