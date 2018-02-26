defmodule Routemaster.Plugs.Parser do
  @moduledoc """
  Parses the request bodies of incoming event delivery requests
  to extract the event list payloads.

  Uses `Routemaster.Drain.JsonDecoder`.
  """

  use Plug.Builder
  alias Routemaster.Drain.Event

  defmodule InvalidPayloadError do
    @moduledoc false
    defexception [:message]
  end

  plug Plug.Parsers, parsers: [:json], json_decoder: Poison

  # If body_params is unfetched, then no parser has run yet.
  # Here we call super() to run the parser configured in this
  # module as a plug.
  #
  def call(conn = %{body_params: %Plug.Conn.Unfetched{}}, opts) do
    conn = super(conn, opts)
    decode_the_events(conn)
  end

  # If the function call matches this, then a parser has
  # already been run. Possibly we're in a Phoenix app.
  #
  def call(conn, _opts) do
    decode_the_events(conn)
  end

  # When decoding JSON with root-level arrays, Poison will merge in the params
  # with a "_json" key. Here we extract them and move them in the assigns.
  #
  defp decode_the_events(conn) do
    events =
      conn.params["_json"]
      |> Enum.map(&cast_and_validate!/1)

    conn
    |> assign(:events, events)
    |> clean_the_params()
  end


  defp clean_the_params(conn) do
    conn = %{conn | body_params: Map.delete(conn.body_params, "_json")}
    conn = %{conn | params: Map.delete(conn.params, "_json")}
    conn
  end


  defp cast_and_validate!(map) do
    event = %Event{
      type: map["type"],
      url: map["url"],
      t: map["t"],
      topic: map["topic"],
      data: map["data"]
    }

    if Event.complete?(event) do
      event
    else
      raise InvalidPayloadError, message: "The events in the received payloads are not complete"
    end
  end
end
