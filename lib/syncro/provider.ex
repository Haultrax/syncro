defmodule Syncro.Provider do
  use GenServer
  require Logger

  @registry :syncro_providers

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(state) do
    {:ok, state, {:continue, :listen}}
  end

  def handle_continue(:listen, state) do
    Phoenix.PubSub.subscribe(Syncro.server(), "request")
    {:noreply, state}
  end

  def handle_info("request", state) do
    Logger.info("[Provider] sync request")
    sync_all()
    {:noreply, state}
  end

  def register(input, opts) do
    register(opts)
    input
  end

  def register(opts) do
    name = Keyword.fetch!(opts, :name)

    sync_thru =
      case Keyword.fetch!(opts, :sync_thru) do
        fun when is_atom(fun) ->
          module =
            self()
            |> Process.info()
            |> Keyword.fetch!(:registered_name)

          {module, fun, []}

        {_module, _fun, _args} = mfa ->
          mfa
      end

    :ets.insert(@registry, {name, sync_thru})
  end

  def sync(name) do
    :ets.tab2list(@registry)
    |> Enum.filter(&(elem(&1, 0) == name))
    |> Enum.each(&fetch_and_sync/1)
  end

  @spec sync(String.t(), any()) :: :ok | {:error, term}
  def sync(name, data) do
    topic = "sync:#{name}"
    Phoenix.PubSub.broadcast(Syncro.server(), topic, {name, data})
  end

  @spec sync_all() :: :ok
  def sync_all() do
    :ets.tab2list(@registry)
    |> Enum.each(&fetch_and_sync/1)
  end

  defp fetch_and_sync({name, {module, fun, args}}) do
    data = apply(module, fun, args)
    sync(name, data)
  end
end
