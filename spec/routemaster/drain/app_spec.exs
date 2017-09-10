defmodule Routemaster.Drain.AppSpec do
  use ESpec
  use Plug.Test

  import Routemaster.TestUtils
  alias Routemaster.Drain.App
  alias Routemaster.Drain.Event
  alias Routemaster.Config
  alias Routemaster.Cache
  alias Plug.Conn

  @opts App.init([])

  # Use this as the URL of the events, so requests will stay local.
  #
  # Tests that check some failure condition (e.g. no auth, bad format),
  # will not execute any request because the plug chain is halted early.
  #
  # Happy path tests will attempt to execute the requests, and these
  # will fail without bypass listening on the port. If we don't care
  # for the side effect (successful response and data fetched), we
  # can let them fail and, since they're async, the tests will still
  # pass.
  #
  @port 33445
  @base_url "http://localhost:#{@port}"


  describe "for valid requests (authenticated POST requests to the root path)" do
    before_all do: clear_redis_test_db(Routemaster.Redis.Data)
    finally do: clear_redis_test_db(Routemaster.Redis.Data)

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

      # and it does nothing.
    end

    context "with some events" do
      let :payload do
        "[#{make_drain_event("/dinosaurs/1", @port)},#{make_drain_event("/dinosaurs/2", @port)}]"
      end

      before do
        clear_redis_test_db(Routemaster.Redis.cache())
        bypass = Bypass.open(port: @port)

        Bypass.expect_once bypass, "GET", "/dinosaurs/1", fn(conn) ->
          conn
          |> Conn.resp(200, ~s<{"dino":1}>)
          |> Conn.put_resp_content_type("application/json")
        end

        Bypass.expect_once bypass, "GET", "/dinosaurs/2", fn(conn) ->
          conn
          |> Conn.resp(200, ~s<{"dino":2}>)
          |> Conn.put_resp_content_type("application/json")
        end

        {:shared, bypass: bypass}
      end

      finally do
        clear_redis_test_db(Routemaster.Redis.cache())
        Bypass.verify_expectations!(shared.bypass)
      end

      defp wait_for_async_fetch_requests_to_complete do
        :timer.sleep(50)
      end


      it "responds with 204 and no body" do
        expect conn().status |> to(eq 204)
        expect conn().resp_body |> to(be_empty())

        wait_for_async_fetch_requests_to_complete()
      end


      it "parses and decodes the JSON" do
        [e1, e2] = decoded_json()

        expect e1 |> to(be_struct Event)
        expect e2 |> to(be_struct Event)

        %Event{data: nil, t: t1, topic: "dinosaurs", type: "update", url: "#{@base_url}/dinosaurs/1"} = e1
        %Event{data: nil, t: t2, topic: "dinosaurs", type: "update", url: "#{@base_url}/dinosaurs/2"} = e2

        expect t1 |> to(be_close_to (now() - 2), 1)
        expect t2 |> to(be_close_to (now() - 2), 1)

        wait_for_async_fetch_requests_to_complete()
      end


      it "fetches and catches the data" do
        {:miss, nil} = Cache.read("#{@base_url}/dinosaurs/1")
        {:miss, nil} = Cache.read("#{@base_url}/dinosaurs/2")

        conn()
        wait_for_async_fetch_requests_to_complete()

        {:ok, %Tesla.Env{status: 200, body: %{"dino" => 1}}} = Cache.read("#{@base_url}/dinosaurs/1")
        {:ok, %Tesla.Env{status: 200, body: %{"dino" => 2}}} = Cache.read("#{@base_url}/dinosaurs/2")
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
