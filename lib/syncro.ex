defmodule Syncro do
  @spec server() :: atom()
  def server(), do: Application.get_env(:syncro, :server, :syncro_pubsub)

  @spec add_notifier((atom, map -> any)) :: :ok | {:error, term}
  def add_notifier(func) when is_function(func, 2) do
    Syncro.Cache.add_notifier(func)
  end
end
