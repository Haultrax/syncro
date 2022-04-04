defmodule Syncro.Cache do
  use GenServer

  require Logger
  alias Syncro.ETS

  @tab :syncro_cache
  @fail_timeout 10 * 1000

  defp log(level, msg), do: Logger.log(level, "[Syncro|Cache] #{msg}")

  def start_link(_opts) do
    state = %{topics: %{}, notifier: nil}
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    ETS.create(@tab, [:set, :protected, :named_table])
    {:ok, state}
  end

  def handle_info({name, data}, state) do
    cache(name, data)

    case state.notifier do
      nil -> nil
      fun -> fun.(name, data)
    end

    {:noreply, state}
  end

  def handle_call(:info, _from, state), do: {:reply, state, state}

  def handle_call({:add_notifier, func}, _from, state) do
    state = Map.put(state, :notifier, func)
    {:reply, :ok, state}
  end

  def handle_call(:force_sync, _from, state) do
    resp = request_sync("forced")
    {:reply, resp, state}
  end

  def handle_call({:subscribe, topic, node}, _from, state) do
    {:ok, state} = subscribe(topic, node, state)
    resp = request_sync(topic)
    {:reply, resp, state}
  end

  def handle_call({:unsubscribe, topic}, _from, state) do
    {:ok, state} = unsubscribe(topic, state)
    {:reply, :ok, state}
  end

  defp request_sync(reason) do
    log(:debug, "sending sync request: #{reason}")
    Phoenix.PubSub.broadcast(Syncro.server(), "request-sync", {"request-sync", node(), reason})
  end

  defp subscribe(topic, node, state) do
    case Map.has_key?(state.topics, topic) do
      false ->
        case Phoenix.PubSub.subscribe(Syncro.server(), topic) do
          :ok ->
            log(:info, "Subscribed to '#{topic}'")
            topics = Map.put(state.topics, topic, node)
            {:ok, Map.put(state, :topics, topics)}

          error ->
            log(:warn, "Unable to subscribe to '#{topic}'")
            log(:error, inspect(error))
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
            log(:info, "Unsubscribed from '#{topic}'")
            topics = Map.drop(state.topics, [topic])
            {:ok, Map.put(state, :topics, topics)}

          error ->
            log(:warn, "Unable to unsubscribe from '#{topic}'")
            log(:error, inspect(error))
            :timer.sleep(@fail_timeout)
            unsubscribe(topic, state)
        end

      _ ->
        {:ok, state}
    end
  end

  defp cache(name, data) do
    log(:debug, "Updating '#{name}'")
    ETS.insert(@tab, name, data)
  end

  def info(), do: GenServer.call(__MODULE__, :info)

  @spec listen(atom, atom) :: :ok | {:error, term}
  def listen(name, node) when is_atom(name) and is_atom(node) do
    GenServer.call(__MODULE__, {:subscribe, "sync:#{name}", node})
  end

  @spec get(atom, any()) :: any()
  def get(name, default \\ nil) when is_atom(name) do
    case :ets.lookup(@tab, name) do
      [{^name, data}] -> data
      _ -> default
    end
  end

  # @spec add_notifier((atom, map -> any)) :: :ok | {:error, term}
  # def add_notifier(func) when is_function(func, 2) do
  #   GenServer.call(__MODULE__, {:add_notifier, func})
  # end

  # @spec force_sync() :: :ok | {:error, term}
  # def force_sync(), do: GenServer.call(__MODULE__, :force_sync)
end
