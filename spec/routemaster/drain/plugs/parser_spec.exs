defmodule Routemaster.Drain.Plugs.ParserSpec do
  use ESpec, async: true
  use Plug.Test
  import Routemaster.TestUtils

  alias Routemaster.Drain.Plugs.Parser

  @opts Parser.init([])
  subject Parser.call(conn(), @opts)

  let :conn do
    conn("POST", "/", body())
    |> put_req_header("content-type", "application/json")
  end

  describe "with an empty body" do
    let :body, do: "[]"

    it "parses JSON bodies and sets it in the assigns" do
      expect Map.get(conn().assigns, :events) |> to(be_nil())
      new_conn = subject()
      expect Map.get(new_conn.assigns, :events) |> to(eq [])
    end
  end

  describe "with some data in the body body" do
    let :body do
      compact_string ~s<
        [
          {"type":"create","url":"http://localhost:4567/foo/1","t":1502651912,"topic":"foo"},
          {"type":"update","url":"http://localhost:4567/bar/1","t":1502651912,"topic":"bar","data":{"qwe":[1,2,3]}},
          {"type":"delete","url":"http://localhost:4567/baz/1","t":1502651912,"topic":"baz"}
        ]
      >
    end

    let :parsed_data do
      [
        %Routemaster.Drain.Event{data: nil, t: 1502651912, topic: "foo",
          type: "create", url: "http://localhost:4567/foo/1"},
       %Routemaster.Drain.Event{data: %{"qwe" => [1, 2, 3]}, t: 1502651912,
          topic: "bar", type: "update", url: "http://localhost:4567/bar/1"},
       %Routemaster.Drain.Event{data: nil, t: 1502651912, topic: "baz",
          type: "delete", url: "http://localhost:4567/baz/1"}
      ]
    end

    it "parses JSON bodies and sets it in the assigns" do
      expect Map.get(conn().assigns, :events) |> to(be_nil())
      new_conn = subject()
      expect Map.get(new_conn.assigns, :events) |> to(eq parsed_data())
    end
  end
end
