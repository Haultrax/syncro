defmodule Syncro.Monitor do
  require Logger
  use GenServer

  # defp log(level, msg), do: Logger.log(level, "[Syncro|Monitor] #{msg}")

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    :net_kernel.monitor_nodes(true)

    {:ok, %{}}
  end

  def handle_info({:nodedown, _nodename}, state) do
    {:noreply, state}
  end

  def handle_info({:nodeup, _nodename}, state) do
    {:noreply, state}
  end
end
