defmodule Routemaster.Plugs.RootPostOnly do
  @moduledoc """
  This should be the first plug to quickly reject requests other
  than `POST /`.

  With a standard `Plug.Router` approach, on the other hand,
  requests must flow through the entire plug chain before being
  matched (HTTP method and path), with the result that the
  other plugs need to be defensive and account for invalid
  requests and raise the right errors. For example the JSON
  parser by default doen't try to parse bodies of GET requests
  (because they don't have a body), which means that the
  `conn.assigns.events` property doesn't get populated.

  Responds with 404 for non `/` requests and with 405 for
  non POST requests. Lets legit requests pass through.
  """

  alias Plug.Conn

  def init(opts), do: opts


  def call(conn = %{method: "POST", request_path: "/"}, _opts) do
    conn
  end

  def call(conn = %{request_path: "/"}, _opts) do
    conn
    |> Conn.send_resp(405, "")
    |> Conn.halt()
  end

  def call(conn, _opts) do
    conn
    |> Conn.send_resp(404, "")
    |> Conn.halt()
  end
end
