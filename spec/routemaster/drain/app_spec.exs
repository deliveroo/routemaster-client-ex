defmodule Routemaster.Drain.AppSpec do
  use ESpec
  use Plug.Test

  import Routemaster.TestUtils
  alias Routemaster.Drain.App
  alias Routemaster.Drain.Event
  alias Routemaster.Config

  @opts App.init([])


  describe "for valid requests (authenticated POST requests to the root path)" do
    let :path, do: "/"
    let :conn, do: post!(path(), payload())
    # JSON bodies with root-level arrays are put in a _json field
    let :decoded_json, do: conn().assigns.events

    context "with no events" do
      let :payload, do: "[]"

      it "responds with 204 and no body" do
        expect conn().status |> to(eq 204)
        expect conn().resp_body |> to(be_empty())
      end

      it "parses and decodes the JSON" do
        expect decoded_json() |> to(eq [])
      end
    end

    context "with some events" do
      let :payload, do: "[#{make_drain_event(1)},#{make_drain_event(2)}]"

      it "responds with 204 and no body" do
        expect conn().status |> to(eq 204)
        expect conn().resp_body |> to(be_empty())
      end

      it "parses and decodes the JSON" do
        [e1, e2] = decoded_json()

        expect e1 |> to(be_struct Event)
        expect e2 |> to(be_struct Event)

        # See `make_drain_event/1` for details.
        %Event{data: nil, t: t1, topic: "dinosaurs", type: "update", url: "https://example.com/dinosaurs/1"} = e1
        %Event{data: nil, t: t2, topic: "dinosaurs", type: "update", url: "https://example.com/dinosaurs/2"} = e2

        expect t1 |> to(be_close_to (now() - 2), 1)
        expect t2 |> to(be_close_to (now() - 2), 1)
      end
    end


    # context "more examples here" do
    #   it "pending" do
    #   end  
    # end
  end


  describe "invalid requests" do
    describe "for POST requests to another path" do
      let :path, do: "/foo"
      let :payload, do: "[]"

      let :conn, do: post!(path(), payload())

      it "responds with 404" do
        expect conn().status |> to(eq 404)
        expect conn().resp_body |> to(be_empty())
      end
    end


    describe "for non-POST requests" do
      let :path, do: "/"
      let :payload, do: "[]"

      let :conn do
        conn("GET", path(), payload())
        |> authenticate()
        |> put_req_header("content-type", "application/json")
        |> App.call(@opts)
      end

      it "responds with 405" do
        expect conn().status |> to(eq 405)
        expect conn().resp_body |> to(be_empty())
      end
    end


    describe "for non-JSON POST requests" do
      let :path, do: "/"
      let :payload, do: "foo=bar"

      let :conn do
        the_conn = 
          conn("POST", path(), payload())
          |> authenticate()
          |> put_req_header("content-type", "application/x-www-form-urlencoded")

        try do
          App.call(the_conn, @opts)
        rescue Plug.Parsers.UnsupportedMediaTypeError -> nil
        end

        the_conn
      end

      it "responds with 415" do
        {status, _headers, body} = sent_resp(conn())

        expect status |> to(eq 415)
        expect body |> to(be_empty())
      end
    end


    describe "for POST requests with invalid JSON" do
      let :path, do: "/"
      let :payload, do: "[{}invalid json!]"

      let :conn do
        the_conn = 
          conn("POST", path(), payload())
          |> authenticate()
          |> put_req_header("content-type", "application/json")

        try do
          App.call(the_conn, @opts)
        rescue Plug.Parsers.ParseError -> nil
        end

        the_conn
      end

      it "responds with 400" do
        {status, _headers, body} = sent_resp(conn())

        expect status |> to(eq 400)
        expect body |> to(be_empty())
      end
    end

    describe "for POST requests without authentication" do
      let :path, do: "/"
      let :payload, do: "[]"

      let :conn, do: unauthenticated_post!(path(), payload())

      it "responds with 401" do
        expect conn().status |> to(eq 401)
        expect conn().resp_body |> to(be_empty())
      end
    end

    describe "for POST requests with unrecognized authentication tokens" do
      let :path, do: "/"
      let :payload, do: "[]"

      let :conn do
        conn("POST", path(), payload())
        |> authenticate("not-a-good-token")
        |> put_req_header("content-type", "application/json")
        |> App.call(@opts)
      end

      it "responds with 403" do
        expect conn().status |> to(eq 403)
        expect conn().resp_body |> to(be_empty())
      end
    end
  end


  # For JSON bodies, the request body (the params) must be a binary
  # and the content-type must be set. Using a Map instead will
  # automatically set the content-type to multipart.
  #
  def unauthenticated_post!(path, body) when is_binary(body) do
    conn("POST", path, body)
    |> put_req_header("content-type", "application/json")
    |> App.call(@opts)
  end

  def post!(path, body) when is_binary(body) do
    conn("POST", path, body)
    |> authenticate()
    |> put_req_header("content-type", "application/json")
    |> App.call(@opts)
  end

  def authenticate(conn, token \\ Config.drain_token) do
    encoded_token = Base.encode64(token <> ":x")
    put_req_header(conn, "authorization", "Basic #{encoded_token}")
  end
end
