defmodule Routemaster.Plugs.Terminator do
  @moduledoc """
  This simply returns 204, the expected response for a Drain app.
  """

  alias Plug.Conn

  def init(opts), do: opts


  def call(conn, _opts) do
    Conn.send_resp(conn, 204, "")
  end
end
