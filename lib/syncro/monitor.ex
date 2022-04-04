defmodule Syncro.Monitor do
  require Logger
  use GenServer

  alias Syncro.{Nodes, Provider, Cache}

  @delay 10_000

  defp log(level, msg), do: Logger.log(level, "[Syncro|Monitor] #{msg}")

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    :net_kernel.monitor_nodes(true)

    attach_listeners()

    {:ok, %{}}
  end

  def handle_info({:nodedown, _nodename}, state) do
    {:noreply, state}
  end

  def handle_info({:nodeup, nodename}, state) do
    if Provider.is_providing?() do
      log(:info, "Connected to #{nodename}")
      Process.send_after(self(), :sync_all, @delay)
    end

    {:noreply, state}
  end

  def handle_info(:sync_all, state) do
    log(:info, "Syncing all data")
    Provider.sync_all()
    {:noreply, state}
  end

  def attach_listeners() do
    Application.get_env(:syncro, :listeners, %{})
    |> Enum.each(fn {name, node_designation} ->
      node = Nodes.designation_to_node(node_designation)
      Cache.listen(name, node)
    end)
  end
end
