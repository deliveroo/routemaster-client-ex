defmodule Routemaster.Drain.Plugs.Parser do
  @moduledoc """
  Parses the request bodies of incoming event delivery requests
  to extract the event list payloads.

  Uses `Routemaster.Drain.JsonDecoder`.
  """

  use Plug.Builder

  plug Plug.Parsers, parsers: [:json], json_decoder: Routemaster.Drain.JsonDecoder

  # When decoding JSON with root-level arrays, Poison will merge in the params
  # with a "_json" key. Here we extract them and move them in the assigns.
  #
  def call(conn, opts) do
    conn = super(conn, opts)
    assign(conn, :events, conn.params["_json"])
  end
end
