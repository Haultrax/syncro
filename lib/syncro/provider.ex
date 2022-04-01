defmodule Syncro.Provider do
  use GenServer
  require Logger
  alias Syncro.ETS

  @registry :syncro_providers

  defp log(level, msg), do: Logger.log(level, "[Syncro|Provider] #{msg}")

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(state) do
    ETS.create(@registry, [:set, :public, :named_table])
    {:ok, state, {:continue, :listen}}
  end

  def handle_continue(:listen, state) do
    Phoenix.PubSub.subscribe(Syncro.server(), "request-sync")
    log(:debug, "Listening for requests")
    {:noreply, state}
  end

  def handle_info({"request-sync", from_node, reason}, state) do
    if from_node != node() do
      log(:debug, "sync request received -- #{reason}")
      sync_all()
    end

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

    ETS.insert(@registry, name, sync_thru)
    sync(name)
  end

  def sync(name) do
    log(:debug, "Syncing '#{name}'")

    ETS.list(@registry)
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
    log(:debug, "Syncing all")

    ETS.list(@registry)
    |> Enum.each(&fetch_and_sync/1)
  end

  defp fetch_and_sync({name, {module, fun, args}}) do
    data = apply(module, fun, args)
    sync(name, data)
  end

  def is_providing?(), do: length(ETS.list(@registry)) > 0
end
