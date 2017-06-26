defmodule Routemaster.Drain.Event do
  @moduledoc """
  An event received by the drain.

  Fields:

  * type, e.g. created, updated
  * url
  * t, a timestamp
  * data, an optional payload
  * topic

  See `Routemaster.Publisher.Event` for the outgoing events.
  """

  defstruct [:type, :url, :t, :data, :topic]
end
