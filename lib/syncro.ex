defmodule Syncro do
  def server(), do: Application.get_env(:syncro, :server, :syncro_pubsub)
end
