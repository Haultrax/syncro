defmodule Syncro.Broadcast do
  def broadcast(topic, msg), do: Phoenix.PubSub.broadcast(Syncro.server(), topic, {topic, msg})
end
