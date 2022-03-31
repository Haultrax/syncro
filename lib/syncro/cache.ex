defmodule Syncro.Cache do
  use GenServer
  require Logger
  alias Syncro.ETS

  @tab :syncro_cache
  @fail_timeout 10 * 1000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(state) do
    ETS.create(@tab, [:set, :protected, :named_table])
    {:ok, state}
  end

  def handle_info({name, data}, state) do
    cache(name, data)
    {:noreply, state}
  end

  def handle_call(:info, _from, state), do: {:reply, state, state}

  def handle_call({:subscribe, topic, node}, _from, state) do
    {:ok, state} = subscribe(topic, node, state)
    Phoenix.PubSub.broadcast(Syncro.server(), "request", "request")
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, topic}, _from, state) do
    {:ok, state} = unsubscribe(topic, state)
    {:reply, :ok, state}
  end

  defp subscribe(topic, node, state) do
    case Map.has_key?(state, topic) do
      false ->
        case Phoenix.PubSub.subscribe(Syncro.server(), topic) do
          :ok ->
            {:ok, Map.put(state, topic, node)}

          error ->
            Logger.warn("[Replicate] Unable to subscribe to '#{topic}'")
            Logger.error(inspect(error))
            :timer.sleep(@fail_timeout)
            subscribe(topic, node, state)
        end

      _ ->
        {:ok, state}
    end
  end

  defp unsubscribe(topic, state) do
    case Map.has_key?(state, topic) do
      false ->
        case Phoenix.PubSub.unsubscribe(Syncro.server(), topic) do
          :ok ->
            {:ok, Map.drop(state, [topic])}

          error ->
            Logger.warn("[Replicate] Unable to unsubscribe from '#{topic}'")
            Logger.error(inspect(error))
            :timer.sleep(@fail_timeout)
            unsubscribe(topic, state)
        end

      _ ->
        {:ok, state}
    end
  end

  defp cache(name, data) do
    IO.puts("---- updating cache")
    ETS.insert(@tab, name, data)
  end

  def info(), do: GenServer.call(__MODULE__, :info)

  @spec listen_sync(atom, atom) :: :ok | {:error, term}
  def listen_sync(name, node) when is_atom(name) and is_atom(node) do
    GenServer.call(__MODULE__, {:subscribe, "sync:#{name}", node})
  end

  @spec get(atom, any()) :: any()
  def get(name, default \\ nil) when is_atom(name) do
    case :ets.lookup(@tab, name) do
      [{^name, data}] -> data
      _ -> default
    end
  end
end
