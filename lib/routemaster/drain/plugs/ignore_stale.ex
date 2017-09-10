defmodule Routemaster.Drain.Plugs.IgnoreStale do
  @moduledoc """
  Drops stale events from the current payload to only include
  events that reflect an entity state that is _more recent_ than
  previously received events.
  
  Helps to ignore events received out-of-order (e.g. an `update`
  event about en entity received after the `delete` event for
  that same entity), given that the Routemaster event bus server
  makes no guarantee of in-order delivery of events.


  ## Implementation Details

  First it removes duplicates by URL from the current payload
  and only preserves the most recent event for each URL.
  Then it compares the timestamp of the remaining events with
  the Redis-backed `Routemaster.Drain.EventState` data, to
  check if the event is newer than the latest known state of
  the resource at that URL.
  If an event is indeed fresher than the latest known state,
  the state is updated in Redis with the timestamp of the
  fresh event.

  Since the output of this middleware should be a single event
  per URL, filtering the events first and only checking the most
  recent one will reduce the number of Redis calls.

  The Redis calls to read and save the event states are executed
  one by one. While reading them in bulk would be more efficient,
  it would not work correctly because multiple batches can be
  received and processed concurrently, and out-of-order events
  for the same resources could be spread in more than one batch.
  """

  alias Routemaster.Drain.EventState
  alias Plug.Conn

  def init(opts), do: opts


  def call(conn, _opts) do
    Conn.assign(conn, :events, filter(conn.assigns.events))
  end


  defp filter(events) do
    events
    |> newest_by_url()
    |> remove_stale_and_update_state()
  end


  defp newest_by_url(events) do
    events
    |> Enum.group_by(fn(e) -> e.url end)
    |> Enum.map(fn({_, list}) -> newest(list) end)
  end


  defp newest(list) do
    Enum.max_by(list, &(&1.t))
  end


  defp remove_stale_and_update_state(events) do
    Enum.filter events, fn(event) ->
      if EventState.fresh?(event) do
        EventState.save(event)
        true
      else
        false
      end
    end
  end
end
