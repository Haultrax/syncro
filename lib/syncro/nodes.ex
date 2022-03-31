defmodule Syncro.Nodes do
  @table :node_register

  @doc """
  Used to register the relationship between reference_name and node_name
  ie. :haul_core -> :"axy@aaa.bbb.ccc"
  """
  @spec configure(map) :: :ok
  def configure(register) do
    :ets.new(@table, [:set, :protected, :named_table])

    Enum.each(register, fn {name, unqualified_nodename} ->
      nodename = Liaison.NodeHelper.to_nodename(unqualified_nodename)
      :ets.insert(@table, {name, nodename})
    end)

    :ok
  end

  @spec designation_to_node(atom) :: atom
  def designation_to_node(designation) do
    try do
      case :ets.lookup(@table, designation) do
        [{^designation, value}] -> value
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  @spec node_to_designation(atom) :: atom
  def node_to_designation(node) do
    :ets.tab2list(@table)
    |> Enum.map(fn {designation, nodename} -> {nodename, designation} end)
    |> Enum.into(%{})
    |> Map.get(node)
  end

  @spec all_nodes() :: keyword()
  def all_nodes(), do: :ets.tab2list(@table)
end
