defmodule Routemaster.Plugs.ParserSpec do
  use ESpec, async: true
  use Plug.Test
  import Routemaster.TestUtils

  alias Routemaster.Plugs.Parser

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

  describe "with some valid data in the body body" do
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

    it "parses JSON bodies and sets it in the assigns as Event structs" do
      expect Map.get(conn().assigns, :events) |> to(be_nil())
      new_conn = subject()
      expect Map.get(new_conn.assigns, :events) |> to(eq parsed_data())
    end



    describe "when the body has already been parsed by the host application" do
      @plug_parsers_opts [
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Poison
      ]

      let :conn do
        conn("POST", "/", body())
        |> put_req_header("content-type", "application/json")
        |> Plug.Parsers.call(Plug.Parsers.init(@plug_parsers_opts))
      end


      it "parses JSON bodies and sets it in the assigns as Event structs" do
        expect Map.get(conn().assigns, :events) |> to(be_nil())
        new_conn = subject()
        expect Map.get(new_conn.assigns, :events) |> to(eq parsed_data())
      end
    end
  end

  describe "with invalid data in the body body" do
    alias Routemaster.Plugs.Parser.InvalidPayloadError

    @port 12311
    @base_url "http://localhost:#{@port}"

    before do
      now = now() - 2
      bad_elements = [
        ~s({"type":"update","topic":"dinosaurs","url":"#{@base_url}/dinosaurs/1"}), # no t
        ~s({"topic":"dinosaurs","url":"#{@base_url}/dinosaurs/2","t":#{now}}), # no type
        ~s({"type":"update","url":"#{@base_url}/dinosaurs/3","t":#{now}}), # no topic
        ~s({"type":"update","topic":"dinosaurs","t":#{now}}), # no url
        ~s({"who am I?":"I am Batman!"}), # na na na na na na na na, Batman!
        ~s({}) # empty
      ]

      {:shared, bad_elements: bad_elements}
    end



    describe "when all the data is bad" do
      let :body do
        "[#{Enum.join(shared.bad_elements, ",")}]"
      end

      it "raises an exception" do
        expect fn() -> subject() end |> to(raise_exception InvalidPayloadError)
      end
    end

    describe "when most of the data is bad" do
      let :body do
        "[#{make_drain_event("/dinosaurs/42", @port)},#{Enum.join(shared.bad_elements, ",")}]"
      end

      it "raises an exception" do
        expect fn() -> subject() end |> to(raise_exception InvalidPayloadError)
      end
    end

    describe "when a single element is bad" do
      let :body do
        [one_bad | _] = shared.bad_elements
        "[#{make_drain_event("/dinosaurs/1", @port)},#{make_drain_event("/dinosaurs/2", @port)},#{one_bad},#{make_drain_event("/dinosaurs/42", @port)}]"
      end

      it "raises an exception" do
        expect fn() -> subject() end |> to(raise_exception InvalidPayloadError)
      end
    end


    describe "when the body has already been parsed by the host application" do
      @plug_parsers_opts [
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Poison
      ]

      let :conn do
        conn("POST", "/", body())
        |> put_req_header("content-type", "application/json")
        |> Plug.Parsers.call(Plug.Parsers.init(@plug_parsers_opts))
      end


      describe "when all the data is bad" do
        let :body do
          "[#{Enum.join(shared.bad_elements, ",")}]"
        end

        it "raises an exception" do
          expect fn() -> subject() end |> to(raise_exception InvalidPayloadError)
        end
      end

      describe "when most of the data is bad" do
        let :body do
          "[#{make_drain_event("/dinosaurs/42", @port)},#{Enum.join(shared.bad_elements, ",")}]"
        end

        it "raises an exception" do
          expect fn() -> subject() end |> to(raise_exception InvalidPayloadError)
        end
      end

      describe "when a single element is bad" do
        let :body do
          [one_bad | _] = shared.bad_elements
          "[#{make_drain_event("/dinosaurs/1", @port)},#{make_drain_event("/dinosaurs/2", @port)},#{one_bad},#{make_drain_event("/dinosaurs/42", @port)}]"
        end

        it "raises an exception" do
          expect fn() -> subject() end |> to(raise_exception InvalidPayloadError)
        end
      end
    end
  end
end


