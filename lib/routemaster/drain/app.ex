defmodule Routemaster.Drain.App do
  @moduledoc """
    A Plug to receive events over HTTP.
  """

  use Plug.Router
  alias Routemaster.Drain

  if Mix.env == :dev do
    # Only log in dev, as the host application already
    # takes care of request loggins in production.
    plug Plug.Logger, log: :debug
  end

  # Invokes `handle_errors/2` callbacks to handle errors and exceptions.
  # After the callbacks are invoked the errors are re-raised.
  # Must be use'd after the debugger.
  use Plug.ErrorHandler

  plug Drain.Plugs.Auth

  # Parse JSON bodies and automatically reject non-JSON requests with a 415 response.
  plug Drain.Plugs.Parser

  plug Drain.Plugs.FetchAndCache

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


  # Either:
  #  - Plug.Parsers.UnsupportedMediaTypeError
  #    The request content-type is not JSON.
  #    Status: 415
  #  - Plug.Parsers.ParseError
  #    The request body is not valid JSON
  #    Status: 400
  #
  # This should not normally happen, and it's ok to handle this
  # with an exception despite the performance hit. The alternative,
  # that is being defensive and checking the content-type for each
  # request, is likely going to have a higher performance impact.
  #
  defp handle_errors(conn, %{kind: :error, reason: %{plug_status: status}, stack: _}) do
    send_resp(conn, status, "")
  end

  defp handle_errors(conn, _), do: conn
end
