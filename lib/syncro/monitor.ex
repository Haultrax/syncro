defmodule Syncro.Monitor do
  require Logger
  use GenServer

  alias Syncro.Provider

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    :net_kernel.monitor_nodes(true)

    Provider.sync_all()

    {:ok, %{}}
  end

  def handle_info({:nodedown, nodename}, state) do
    Logger.info("[Disconnected] #{nodename}")
    {:noreply, state}
  end

  def handle_info({:nodeup, nodename}, state) do
    Logger.info("[Connected] #{nodename} -- syncing")
    Provider.sync_all()
    {:noreply, state}
  end
end
