defmodule Routemaster.Plugs.TerminatorSpec do
  use ESpec, async: true
  use Plug.Test

  alias Routemaster.Plugs.Terminator

  @opts Terminator.init([])

  subject Terminator.call(conn(), @opts)

  let :conn, do: conn("POST", "/")

  it "responds with 204 with no body" do
    expect subject().status |> to(eq 204)
    expect subject().resp_body |> to(eq "")
  end
end
