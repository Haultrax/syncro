defmodule Syncro.Cache do
  use GenServer

  require Logger
  alias Syncro.ETS

  @tab :syncro_cache
  @fail_timeout 10 * 1000

  defp log(level, msg), do: Logger.log(level, "[Syncro|Cache] #{msg}")

  def start_link(_opts) do
    state = %{}
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    ETS.create(@tab, [:set, :protected, :named_table])
    {:ok, state}
  end

  def handle_info({"sync:" <> _topic, name, data}, state) do
    cache_data(name, data)

    {:noreply, state}
  end

  def handle_call(:info, _from, state), do: {:reply, state, state}

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

  defp subscribe(topic, node, topics) do
    case Map.has_key?(topics, topic) do
      false ->
        case Phoenix.PubSub.subscribe(Syncro.server(), topic) do
          :ok ->
            log(:info, "Subscribed to '#{topic}'")
            topics = Map.put(topics, topic, node)
            {:ok, Map.put(topics, :topics, topics)}

          error ->
            log(:warn, "Unable to subscribe to '#{topic}'")
            log(:error, inspect(error))
            :timer.sleep(@fail_timeout)
            subscribe(topic, node, topics)
        end

      _ ->
        {:ok, topics}
    end
  end

  defp unsubscribe(topic, topics) do
    case Map.has_key?(topics, topic) do
      false ->
        case Phoenix.PubSub.unsubscribe(Syncro.server(), topic) do
          :ok ->
            log(:info, "Unsubscribed from '#{topic}'")
            topics = Map.drop(topics, [topic])
            {:ok, Map.put(topics, :topics, topics)}

          error ->
            log(:warn, "Unable to unsubscribe from '#{topic}'")
            log(:error, inspect(error))
            :timer.sleep(@fail_timeout)
            unsubscribe(topic, topics)
        end

      _ ->
        {:ok, topics}
    end
  end

  defp cache_data(name, data) do
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
end
