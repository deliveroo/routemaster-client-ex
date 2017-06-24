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

  # Enable to decode JSON bodies
  # plug Plug.Parsers, parsers: [:json]

  plug :match
  plug :dispatch

  @doc false
  def init(opts) do
    Application.ensure_started(:routemaster)
    super(opts)
  end


  get "/" do
    send_resp(conn, 200, "")
  end


  match _ do
    send_resp(conn, 404, "")
  end
end
