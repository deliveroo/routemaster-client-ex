defmodule Routemaster.Drain.App do
  @moduledoc """
  A Plug to receive events over HTTP.
  """

  use Plug.Builder
  alias Routemaster.Drain

  if Mix.env == :dev do
    # Only log in dev, as the host application already
    # takes care of request logging in production.
    plug Plug.Logger, log: :debug
  end

  # Invokes `handle_errors/2` callbacks to handle errors and exceptions.
  # After the callbacks are invoked the errors are re-raised.
  # Must be use'd after the debugger.
  use Plug.ErrorHandler

  plug Drain.Plugs.RootPostOnly

  plug Drain.Plugs.Auth

  # Parse JSON bodies and automatically reject non-JSON requests with a 415 response.
  plug Drain.Plugs.Parser

  plug Drain.Plugs.FetchAndCache

  plug Drain.Plugs.Terminator

  @doc false
  def init(opts) do
    Application.ensure_started(:routemaster)
    super(opts)
  end

  # Make the compile-time options available to each request.
  # This allows to customize some nested module with options
  # passed to the public drain app.
  #
  # Available data:
  #  - conn.assigns.events
  #  - conn.assigns.init_opts
  #
  @doc false
  def call(conn, opts) do
    conn
    |> assign(:init_opts, opts)
    |> super(opts)
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
