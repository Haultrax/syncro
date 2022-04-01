defmodule Syncro.Cache do
  alias Syncro.ETS

  @spec registry() :: atom()
  def registry(), do: Application.get_env(:syncro, :cache, :syncro_cache)

  @spec create((atom, any -> any) | nil) :: :ok
  def create(callback) when is_nil(callback) or is_function(callback, 2) do
    ETS.create(registry(), [:set, :public, :named_table])
    set_callback(callback)
  end

  @spec set_callback((atom, any -> any) | nil) :: :ok
  def set_callback(callback) when is_nil(callback) or is_function(callback, 2) do
    ETS.insert(registry(), :syncro_callback, callback)
  end

  @spec get(atom, any()) :: any()
  def get(name, default \\ nil) when is_atom(name) do
    ETS.get(registry(), name, default)
  end

  @spec update(atom, any) :: no_return()
  def update(name, data) do
    register = registry()
    ETS.insert(register, name, data)

    case ETS.get(register, :syncro_callback) do
      nil -> nil
      callback -> callback.(name, data)
    end
  end
end
