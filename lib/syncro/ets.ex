defmodule Syncro.ETS do
  @spec create(atom, Keyword.t()) :: :ok | :exists
  def create(name, opts \\ []) when is_atom(name) do
    try do
      :ets.new(name, opts)
    rescue
      _ -> :exists
    end
  end

  @spec insert(atom | pid, atom, any) :: :ok
  def insert(tab, key, value) when is_atom(key) do
    :ets.insert(tab, {key, value})
  end

  @spec get(atom | pid, atom, any) :: any
  def get(tab, key, default \\ nil) when is_atom(key) do
    try do
      case :ets.lookup(tab, key) do
        [{^key, value}] -> value
        _ -> default
      end
    rescue
      _ -> default
    end
  end

  @spec list(atom | pid) :: list()
  def list(tab), do: :ets.tab2list(tab)
end
