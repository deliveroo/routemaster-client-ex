defmodule Routemaster.Publisher.Event do
  @moduledoc """
  An event to be published to the bus.

  This is _not_ defined as a struct because we do not want missing
  values to default to nil. With a struct, in fact, missing fields
  would still be present with their keys pointing to nil values,
  and the generated JSON would be larger.

  Fields

  * `type`, e.g. created, updated.
  * `url`, the canonical URL where the resource can be found.
  * `timestamp`, time of the event (optional).
  * `data`, an optional payload (optional).

  See `Routemaster.Drain.Event` for the incoming events.
  """

  alias Routemaster.Utils


  @doc """
  Builds a compact Map from the four event attributes, ignoring `nil` data
  values. The timestamp is always set.
  """
  def build(type, url, nil, nil) do
    %{type: type, url: url, timestamp: Utils.now()}
  end

  def build(type, url, timestamp, nil) do
    %{type: type, url: url, timestamp: timestamp}
  end

  def build(type, url, nil, data) do
    %{type: type, url: url, timestamp: Utils.now(), data: data}
  end

  def build(type, url, timestamp, data) do
    %{type: type, url: url, timestamp: timestamp, data: data}
  end


  def validate!(event) do
    _valid_url! event.url
    _valid_timestamp! event.timestamp
  end

  defp _valid_url!(url) do
    unless Utils.valid_url?(url) do
      raise __MODULE__.ValidationError, message: "invalid url: #{inspect url}."
    end
  end

  defp _valid_timestamp!(nil), do: nil
  defp _valid_timestamp!(timestamp) when is_integer(timestamp), do: nil
  defp _valid_timestamp!(timestamp) do
    raise __MODULE__.ValidationError, message: "invalid timestamp: #{inspect timestamp}."
  end


  defmodule ValidationError do
    @moduledoc false
    defexception [:message]
  end
end
