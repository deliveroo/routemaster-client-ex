defmodule Routemaster.Drains.Siphon do
  @moduledoc """
  Allows to pluck events for one or more topics and remove them
  from the current payload. The removed -- siphoned -- events
  are sent to a siphon module that must implement the `call/1`
  function, that will be invoked with a list of `Routemaster.Drain.Event`
  structures as argument.

  The listeners' `call/1` function is invoked in a supervised `Task`,
  so all listeners are to be considered asynchronous and independent.

  This drain plug is very similar to the `Routemaster.Drains.Notify`
  module, with the difference that it modifies the event list in the
  current payload before passing it downstream to the next drain in
  the pipeline.

  It's meant to be used when some topic should not be processed
  with the rest of the drain pipeline, and you want to extract
  it from the stream before it reaches the next drains.
  A common use case is when you care about every single event
  for a topic (e.g. fast changing resources where each event
  carries a data payload), and these need to be processed
  separately before a `Routemaster.Drains.Dedup` or
  `Routemaster.Drains.IgnoreStale` drain can discard any of them.


  ### Options

  * `:topic` (or `:topics`, plural): either a binary or a list of
  binaries. This is the topic or topics that will be removed from
  the current payload and sent to the siphon module.
  * `:to`: the siphon module that will receive the events.

  ### Examples

  ```elixir
  alias Routemaster.Drains.Siphon

  drain Siphon, topic: "burgers", to: BurgerSiphon
  drain Siphon, topics: ~(coke fanta), to: DrinksSiphon
  ```
  """

  @supervisor DrainEvents.TaskSupervisor


  def init(opts) do
    topic = fetch_topic!(opts)
    siphon = Keyword.fetch!(opts, :to)

    [topic: topic, siphon: siphon]
  end



  def call(conn, [topic: topic, siphon: siphon]) do
    {matched, others} = partition(conn.assigns.events, topic)
    send_to_siphon(matched, siphon)
    Plug.Conn.assign(conn, :events, others)
  end


  defp send_to_siphon([], _), do: nil
  defp send_to_siphon(events, siphon) do
    Task.Supervisor.start_child(@supervisor, fn() ->
      siphon.call(events)
    end)
  end


  defp fetch_topic!(kw) do
    case Keyword.get(kw, :topic, Keyword.get(kw, :topics)) do
      nil ->
        raise KeyError, key: ":topic or :topics", term: kw
      topic ->
        topic
    end
  end


  defp partition(events, topics) when is_list(topics) do
    Enum.split_with(events, &(&1.topic in topics))
  end

  defp partition(events, topic) do
    Enum.split_with(events, &(&1.topic == topic))
  end
end
