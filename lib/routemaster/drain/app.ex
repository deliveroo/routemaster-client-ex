defmodule Routemaster.Drain.App do
  @moduledoc """
    A Plug to receive events over HTTP.
  """

  use Plug.Router


  if Mix.env == :dev do
    use Plug.Debugger, otp_app: :routemaster

    # Only log in dev, as the host application already
    # takes care of request loggins in production.
    plug Plug.Logger, log: :debug
  end


  # reject with 415 non-json requests
  plug :only_accept_json


  # Enable to decode JSON bodies
  # plug Plug.Parsers, parsers: [:json]


  # required by Plug
  plug :match
  plug :dispatch


  @doc false
  def init(opts) do
    Application.ensure_started(:routemaster)
    super(opts)
  end


  # Main (only?) endpoint, to receive events from the event bus
  #
  post "/" do
    send_resp(conn, 204, "")
  end


  # black hole for all other requests
  #
  match _ do
    status = if conn.method == "POST", do: 404, else: 405
    send_resp(conn, status, "")
  end


  defp only_accept_json(conn, _opts) do
    if get_req_content_type(conn) == "application/json" do
      conn
    else
      conn |> send_resp(415, "") |> halt()
    end
  end


  defp get_req_content_type(conn) do
    conn
    |> get_req_header("content-type")
    |> hd()
    |> String.downcase()
  end
end
