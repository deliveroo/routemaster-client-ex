defmodule Routemaster.Drain.Plugs.ParserSpec do
  use ESpec, async: true
  use Plug.Test

  alias Routemaster.Drain.Plugs.Parser

  @opts Parser.init([])

  let :conn do
    conn("POST", "/", "[]")
    |> put_req_header("content-type", "application/json")
  end

  it "parses JSON bodies and sets it in the assigns" do
    expect Map.get(conn().assigns, :events) |> to(be_nil())
    new_conn = Parser.call(conn(), @opts)
    expect Map.get(new_conn.assigns, :events) |> to(eq [])
  end
end
