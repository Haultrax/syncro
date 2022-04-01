defmodule Syncro.Direct do
  alias Syncro.Nodes

  @spec call(atom, module, fun, list) ::
          {:ok, any} | {:error, :unknown_name | :nodedown | term}
  def call(designation, module, func, args) do
    case Nodes.designation_to_node(designation) do
      nil ->
        {:error, :unknown_name}

      nodename ->
        case :rpc.call(nodename, module, func, args) do
          {:badrpc, :nodedown} -> {:error, :nodedown}
          {:badrpc, reason} -> {:error, reason}
          resp -> resp
        end
    end
  end
end
