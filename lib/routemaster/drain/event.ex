defmodule Routemaster.Drain.Event do
  @moduledoc """
  An event received by the drain.

  ## Fields:

  * `type`, e.g. created, updated.
  * `url`, the canonical URL where the resource can be found.
  * `t`, the timestamp of when the event was emitted,
  * `data`, an optional payload.
  * `topic`, the topic of the event.

  See `Routemaster.Publisher.Event` for the outgoing events.
  """

  @type type :: binary
  @type url :: binary
  @type timestamp :: non_neg_integer
  @type data :: (map | list)
  @type topic :: binary

  @type t :: %{
    :__struct__ => __MODULE__,
    required(:type) => type,
    required(:url) => url,
    required(:t) => timestamp,
    required(:topic) => topic,
    optional(:data) => data
  }

  defstruct [:type, :url, :t, :data, :topic]

  @required_fields [:type, :url, :t, :topic]


  @doc """
  Verifies if an event contains all the mandatory fields.
  """
  @spec complete?(t) :: boolean
  def complete?(event) do
    Enum.all?(@required_fields, fn(field) -> Map.get(event, field) end)
  end
end
