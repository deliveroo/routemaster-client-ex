defmodule Routemaster.Drain.Plugs.FetchAndCacheSpec do
  use ESpec
  use Plug.Test
  import Routemaster.TestUtils

  alias Routemaster.Drain.Plugs.FetchAndCache
  alias Routemaster.Cache
  alias Plug.Conn

  before_all do: clear_redis_test_db(Routemaster.Redis.cache())

  before do
    bypass = Bypass.open(port: 4567)
    {:shared, bypass: bypass}
  end

  finally do
    clear_redis_test_db(Routemaster.Redis.cache())
    Bypass.verify_expectations!(shared.bypass)
  end

  @opts FetchAndCache.init([])

  subject FetchAndCache.call(conn(), @opts)

  let :conn do
    conn("POST", "/") |> assign(:events, events())
  end


  describe "with no events" do
    let :events, do: []

    it "returns a conn" do
      expect subject() |> to(be_struct Plug.Conn)
    end

    it "does nothing" do
      allow Task.Supervisor |> to(
        accept :start_child, fn(_supervisor, _fn) ->
          raise "Test Error: I should never be invoked"
        end
      )
      
      expect fn -> subject() end
      |> to_not(raise_exception RuntimeError, "Test Error: I should never be invoked")
    end
  end


  describe "with some events" do
    let :events do
      [
        %Routemaster.Drain.Event{data: nil, t: 1502651912, topic: "foo",
          type: "create", url: "http://localhost:4567/foo/1"},
       %Routemaster.Drain.Event{data: %{"qwe" => [1, 2, 3]}, t: 1502651912,
          topic: "bar", type: "update", url: "http://localhost:4567/bar/2"},
       %Routemaster.Drain.Event{data: nil, t: 1502651912, topic: "baz",
          type: "delete", url: "http://localhost:4567/baz/3"}
      ]
    end

    before do
      Bypass.expect_once shared.bypass, "GET", "/foo/1" , fn conn ->
        Conn.resp(conn, 200, ~s<{"foo":1}>)
      end

      Bypass.expect_once shared.bypass, "GET", "/bar/2" , fn conn ->
        Conn.resp(conn, 200, ~s<{"bar":2}>)
      end

      Bypass.expect_once shared.bypass, "GET", "/baz/3" , fn conn ->
        Conn.resp(conn, 200, ~s<{"baz":3}>)
      end
    end

    context "when there is no previously cached value" do
      it "fetches the resources and populate their caches" do
        {:miss, nil} = Cache.read("http://localhost:4567/foo/1")
        {:miss, nil} = Cache.read("http://localhost:4567/bar/2")
        {:miss, nil} = Cache.read("http://localhost:4567/baz/3")

        subject()
        :timer.sleep(100)

        {:ok, %Tesla.Env{status: 200, body: "{\"foo\":1}"}} = Cache.read("http://localhost:4567/foo/1")
        {:ok, %Tesla.Env{status: 200, body: "{\"bar\":2}"}} = Cache.read("http://localhost:4567/bar/2")
        {:ok, %Tesla.Env{status: 200, body: "{\"baz\":3}"}} = Cache.read("http://localhost:4567/baz/3")
      end
    end

    context "when there are some previously cached values" do
      before do
        Cache.write("http://localhost:4567/foo/1", 1234)
        Cache.write("http://localhost:4567/bar/2", 1234)
        Cache.write("http://localhost:4567/baz/3", 1234)
      end

      it "fetches the resources and populate their caches" do
        {:ok, 1234} = Cache.read("http://localhost:4567/foo/1")
        {:ok, 1234} = Cache.read("http://localhost:4567/bar/2")
        {:ok, 1234} = Cache.read("http://localhost:4567/baz/3")

        subject()
        :timer.sleep(100)

        {:ok, %Tesla.Env{status: 200, body: "{\"foo\":1}"}} = Cache.read("http://localhost:4567/foo/1")
        {:ok, %Tesla.Env{status: 200, body: "{\"bar\":2}"}} = Cache.read("http://localhost:4567/bar/2")
        {:ok, %Tesla.Env{status: 200, body: "{\"baz\":3}"}} = Cache.read("http://localhost:4567/baz/3")
      end
    end
  end
end
