defmodule Routemaster.Drains.Notify do
  @moduledoc """
  Drain plug to declare listener modules that will be notified
  of the received events. Listeners must implement the `call/1`
  function, that will be invoked with a list of `Routemaster.Drain.Event`
  structures as argument.

  The listeners' `call/1` function is invoked in a supervised `Task`,
  so all listeners are to be considered asynchronous and independent.

  By default a listener module will be notified of all events in the
  current payload, but it's possible to filter by topic. It's also
  possible to subscribe multiple listeners at the same time.
  This is convenient when topic filters are applied, because the
  filtering function will be executed only once for all the listeners
  declared together.

  ### Options

  * `:listener` (or `:listeners`, plural): either the listener module
  or a list of listener modules.
  * `:only`: either a binary or a list of binaries. The listener will
  only be notified of events for this topic or topics.
  * `:except`: either a binary or a list of binaries. The opposite
  of `:only`.

  If no events match the filters, listeners are not notified. This
  means that the listeners' `call/1` functions are never invoked
  with empty lists.

  After notifying the listener(s), the full event payload is passed
  down in the pipeline unchanged, which means that multiple `Notify`
  drains can be configured together.

  ### Examples

  ```elixir
  alias Routemaster.Drains.Notify

  # listen to all events from all topics
  drain Notify, listener: GlobalListener

  # only listen to one or some topics
  drain Notify, listener: BurgerListener, only: "burgers"
  drain Notify, listener: FruitListener, only: ~w(apple orange)

  # listen to all but some topics
  drain Notify, listener: VeggieListener, except: "meat"
  drain Notify, listener: NoFishListener, except: ~w(cod seabass)

  # notify multiple listeners for a selection of topics
  drain Notify,
    listeners: [DessertListener, SweetListener],
    only: ~w(pies cakes ice_creams)
  ```
  """

  @supervisor DrainEvents.TaskSupervisor


  def init(opts) do
    listeners = fetch_listeners!(opts)

    filter =
      case {Keyword.fetch(opts, :only), Keyword.fetch(opts, :except)} do
        {:error, :error} ->
          :all
        {{:ok, only}, :error} ->
          {:only, normalize(only)}
        {:error, {:ok, except}} ->
          {:except, normalize(except)}
        _ ->
          raise "The #{__MODULE__} drain can't be configured with both :only and :except filters"
      end

    [listeners: listeners, filter: filter]
  end


  defp fetch_listeners!(kw) do
    case Keyword.get(kw, :listener, Keyword.get(kw, :listeners)) do
      nil ->
        raise KeyError, key: ":listener or :listeners", term: kw
      listeners ->
        List.wrap(listeners)
    end
  end


  defp normalize(topics) when is_list(topics) do
    topics
    |> List.flatten()
    |> Enum.map(&normalize/1)
  end
  defp normalize(topic) when is_binary(topic), do: topic
  defp normalize(topic), do: to_string(topic)


  def call(conn, [listeners: listeners, filter: filter]) do
    events = select(conn.assigns.events, filter)
    notify(events, listeners)
    conn
  end


  defp notify([], _), do: nil
  defp notify(events, listeners) do
    for listener <- listeners do
      Task.Supervisor.start_child(@supervisor, fn() ->
        listener.call(events)
      end)
    end
  end


  defp select(events, :all), do: events

  defp select(events, {:only, target}) do
    Enum.filter(events, &match(&1.topic, target))
  end

  defp select(events, {:except, target}) do
    Enum.reject(events, &match(&1.topic, target))
  end


  defp match(item, target) when is_list(target) do
    item in target
  end

  defp match(item, target) do
    item == target
  end
end
