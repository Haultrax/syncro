defmodule Syncro.Provider do
  alias Syncro.ETS
  require Logger

  defp log(level, msg), do: Logger.log(level, "[Syncro|Provider] #{msg}")

  @spec registry() :: atom
  def registry(), do: Application.get_env(:syncro, :provider, :syncro_provider)

  @spec create() :: :ok | :exists
  def create(), do: ETS.create(registry(), [:set, :public, :named_table])

  @spec register(atom, fun) :: :ok
  def register(name, sync_from) when is_atom(name) and is_function(sync_from, 0) do
    log(:info, "registered => '#{name}'")
    ETS.insert(registry(), name, sync_from)
  end

  def sync(name) do
    case ETS.get(registry(), name) do
      nil ->
        log(:debug, "cannot sync '#{name}' as it is not registered")

      callback ->
        log(:debug, "syncing '#{name}'")
        sync(name, callback.())
    end
  end

  @spec sync(String.t(), any()) :: :ok | {:error, term}
  def sync(name, data) do
    Enum.each(Node.list(), fn nodename ->
      case :rpc.call(nodename, Syncro.Cache, :update, [name, data]) |> IO.inspect() do
        {:badrpc, :nodedown} -> {:error, :nodedown}
        {:badrpc, reason} -> {:error, reason}
        resp -> resp
      end
    end)
  end

  @spec sync_all() :: :ok
  def sync_all() do
    log(:debug, "Syncing all")

    ETS.list(registry())
    |> Enum.map(&sync/1)
  end

  def is_providing?(), do: length(ETS.list(registry())) > 0
end
