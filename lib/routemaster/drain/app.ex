defmodule Routemaster.Drain.App do
  @moduledoc """
    A Plug to receive events over HTTP.
  """
  alias Plug.Parsers.UnsupportedMediaTypeError

  use Plug.Router

  if Mix.env == :dev do
    # Only log in dev, as the host application already
    # takes care of request loggins in production.
    plug Plug.Logger, log: :debug
  end

  # Invokes `handle_errors/2` callbacks to handle errors and exceptions.
  # After the callbacks are invoked the errors are re-raised.
  # Must be use'd after the debugger.
  use Plug.ErrorHandler


  # Parse JSON bodies and automaticaly reject non-JSON requests
  # with a 415 response.
  plug Plug.Parsers, parsers: [:json], json_decoder: Poison

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


  # This should not normally happen, and it's ok to handle this
  # with an exception despite the performance hit. The alternative,
  # that is being defensive and checking the content-type for each
  # request, is likely going to have a higher performance impact.
  #
  defp handle_errors(conn, %{kind: :error, reason: %UnsupportedMediaTypeError{media_type: _wrong_type}, stack: _}) do
    send_resp(conn, 415, "")
  end
  defp handle_errors(conn, _), do: conn
end
