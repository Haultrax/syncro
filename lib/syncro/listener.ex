defmodule Syncro.Listener do
  defmacro __using__(_opts) do
    quote do
      @on_definition unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      @callback handle_in(event :: String.t(), payload :: any) :: any

      use GenServer
      require Logger

      @type topic :: String.t()
      @type message :: term

      def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

      def init(state) do
        Enum.each(topic_set(), fn topic ->
          Logger.debug("#{__MODULE__} | subscribing to '#{topic}'")
          :ok = Phoenix.PubSub.subscribe(Syncro.server(), topic)
        end)

        {:ok, state}
      end

      def handle_info({topic, msg}, state) do
        case MapSet.member?(topic_set(), topic) do
          true ->
            handle_in(topic, msg)

          _ ->
            Logger.warn("#{__MODULE__} | Not handling recieved topic '#{topic}'")
        end

        {:noreply, state}
      end

      def handle_info({topic, _name, msg}, state) do
        case MapSet.member?(topic_set(), topic) do
          true ->
            handle_in(topic, msg)

          _ ->
            Logger.warn("#{__MODULE__} | Not handling recieved topic '#{topic}'")
        end

        {:noreply, state}
      end

      def topic_set(), do: apply(__MODULE__, :__topic_set__, [])
    end
  end

  defmacro __before_compile__(_env) do
    topic_set =
      __CALLER__.module
      |> Module.get_attribute(:topics, [])
      |> MapSet.new()

    quote do
      def __topic_set__, do: unquote(Macro.escape(topic_set))
    end
  end

  def __on_definition__(env, _kind, :handle_in, [topic | _], _guards, _body) do
    targ_mod = hd(env.context_modules)
    topics = Module.get_attribute(targ_mod, :topics, [])
    Module.put_attribute(targ_mod, :topics, [topic | topics])
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: :ok
end
