defmodule Routemaster.Drain.JsonDecoder do
  @moduledoc """
  Wraps Poison to explicitly decode JSON into `%Drain.Event{}` structures.
  """
  alias Routemaster.Drain.Event

  @required_fields [:t, :type, :topic, :url]


  defmodule InvalidPayloadError do
    @moduledoc false
    defexception [:message]
  end


  @doc """
  This function is the only [expected interface](https://github.com/elixir-lang/plug/blob/v1.3.5/lib/plug/parsers/json.ex#L47)
  for the decoder objects.

  The caller expects this to raise exceptions in case of failures.

  This decoder is only used to parse JSON payloads received from the bus.
  Since the body should always be a list, if it's not raise an error.
  """
  def decode!(body) do
    case Poison.decode!(body, as: [%Event{}]) do
      list when is_list(list) ->
        validate!(list)
      _ ->
        raise InvalidPayloadError, message: "Received payload is not an array"
    end
  end


  defp validate!(list) do
    if all_events_complete?(list) do
      list
    else
      raise InvalidPayloadError, message: "The events in the received payloads are not complete"
    end
  end


  defp all_events_complete?([]), do: true
  defp all_events_complete?(list) do
    Enum.all?(list, fn(event) ->
      Enum.all?(@required_fields, fn(field) -> Map.get(event, field) end)
    end)
  end
end