defmodule Routemaster.Drain.Plugs.Dedup do
  @moduledoc """
  Removes duplicates (by url and type) from the event list and
  only preserves the most recent event.

  This is only scoped to the current event payload, while in
  fact the Drain app could receive concurrent requests with
  separate payloads and duplicates _across the payloads_.

  For that reason, this plug is not really meant to ensure
  global event uniqueness, but just to grab some low-hanging
  fruit and decrease the workload for the next plugs.
  """

  alias Plug.Conn
  
  def init(opts), do: opts


  def call(conn, _opts) do
    Conn.assign(conn, :events, filter(conn.assigns.events))
  end


  defp filter(events) do
    events
    |> Enum.group_by(fn(e) -> [e.url, e.type] end)
    |> Enum.map(fn({_, list}) -> newest(list) end)
  end


  # Sorts by timestamp in descending order,
  # then returns the first item (the newest).
  #
  defp newest(list) do
    Enum.max_by(list, &(&1.t))
  end
end
