defmodule Routemaster.Publisher.Event do
  @moduledoc """
  An event to be published to the bus.

  Fields

  * type, e.g. created, updated
  * url
  * timestamp
  * data, an optional payload

  See `Routemaster.Drain.Event` for the incoming events.
  """

  defstruct [:type, :url, :timestamp, :data]
end
