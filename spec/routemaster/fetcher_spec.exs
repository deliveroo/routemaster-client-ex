defmodule Routemaster.FetcherSpec do
  use ESpec

  import Routemaster.TestUtils
  alias Routemaster.Fetcher
  alias Routemaster.Cache
  alias Plug.Conn

  # Based on the `service_auth_credentials` for localhost
  # configured for the test environment.
  @localhost_basic_auth "Basic YS11c2VyOmEtdG9rZW4="

  describe "authenticate!" do
    let :env, do: %Tesla.Env{url: url()}

    # Passing an empty list for the Testla stack will ensure
    # that "Tesla.run(env, next)" is a noop.
    #
    subject Fetcher.authenticate!(env(), [])

    context "with a known host" do
      let :url, do: "https://localhost/hamsters/1"

      it "sets the Authentication HTTP header in the env" do
        %Tesla.Env{headers: headers} = env()
        expect headers |> to(be_map())
        expect headers |> to(be_empty())
        expect headers["Authorization"] |> to(be_nil())

        %Tesla.Env{headers: headers} = subject()
        expect headers |> to(be_map())
        expect headers |> to_not(be_empty())
        expect headers["Authorization"] |> to(eq @localhost_basic_auth)
      end
    end

    context "with an unknown host" do
      let :url, do: "https://unknown.com/rabbits/1"

      it "raises an exception" do
        expect fn()-> subject() end
        |> to(raise_exception RuntimeError, "Unknown credentials for unknown.com")
      end
    end
  end


  describe "get(url)" do
    before_all do: clear_redis_test_db(Routemaster.Redis.cache())

    before do
      bypass = Bypass.open(port: 4567)
      {:shared, bypass: bypass}
    end

    finally do
      clear_redis_test_db(Routemaster.Redis.cache())
      Bypass.verify_expectations!(shared.bypass)
    end

    defp make_url(path) do
      "http://localhost:4567" <> path
    end

    subject Fetcher.get(make_url("/foo/1"))


    it "sets the correct user-agent HTTP header" do
      Bypass.expect_once shared.bypass, "GET", "/foo/1", fn conn ->
        [ua|[]] = Conn.get_req_header conn, "user-agent"
        expect ua |> to(start_with "routemaster-client-ex-v")

        conn
        |> Conn.resp(200, "{}")
        |> Conn.put_resp_content_type("application/json")
      end

      subject()
    end


    it "sets the correct Authorization HTTP header" do
      Bypass.expect_once shared.bypass, "GET", "/foo/1", fn conn ->
        [auth_h|[]] = Conn.get_req_header conn, "authorization"
        expect auth_h |> to(eq @localhost_basic_auth)

        conn
        |> Conn.resp(200, "{}")
        |> Conn.put_resp_content_type("application/json")
      end

      subject()
    end


    it "sets an 'application/json' Accept HTTP header" do
      Bypass.expect_once shared.bypass, "GET", "/foo/1", fn conn ->
        [accept_h|[]] = Conn.get_req_header conn, "accept"
        expect accept_h |> to(eq "application/json")

        conn
        |> Conn.resp(200, "{}")
        |> Conn.put_resp_content_type("application/json")
      end

      subject()
    end


    describe "the response, with no cached value" do
      before do
        response_status = status()
        response_body = raw_body()
        Bypass.expect_once shared.bypass, "GET", "/foo/1", fn conn ->
          conn
          |> Conn.resp(response_status, response_body)
          |> Conn.put_resp_content_type("application/json")
        end
      end

      context "with a successful response" do
        let :status, do: 200
        let :raw_body do
          compact_string ~s<
            {
              "foo" : "bar",
              "qwe" : [1, 2, 3, "hello"],
              "asd" : { "a" : 11, "b" : 22 }
            }
          >
        end

        let :parsed_body do
          %{
            "foo" => "bar",
            "qwe" => [1, 2, 3, "hello"],
            "asd" => %{"a" => 11, "b" => 22}
          }
        end

        it "returns the decoded body" do
          {:ok, data} = subject()
          expect data |> to(eq parsed_body())
        end

        context "when the cache layer is enabled (the default)" do
          it "caches the response" do
            req_url = make_url("/foo/1")

            expect Cache.read(req_url) |> to(eq {:miss, nil})
            {:ok, data} = subject()
            expect Cache.read(req_url) |> to_not(eq {:miss, nil})

            {:ok, %{body: ^data}} = Cache.read(req_url)
          end
        end

        context "when the cache layer is NOT enabled (the default)" do
          subject Fetcher.get(make_url("/foo/1"), cache: false)

          it "does NOT cache the response" do
            req_url = make_url("/foo/1")

            expect Cache.read(req_url) |> to(eq {:miss, nil})
            subject()
            expect Cache.read(req_url) |> to(eq {:miss, nil})
          end
        end
      end

      context "with a NON successful response" do
        let :status, do: 400
        let :raw_body, do: ""

        it "returns an error with the HTTP status code" do
          expect subject() |> to(eq {:error, 400})
        end

        it "does NOT cache the response even though the cache layer is enabled (the default)" do
          req_url = make_url("/foo/1")

          expect Cache.read(req_url) |> to(eq {:miss, nil})
          {:error, 400} = subject()
          expect Cache.read(req_url) |> to(eq {:miss, nil})
        end
      end
    end


    describe "the response, if a cached response is available" do
      let :url_path, do: "/foo/1"
      let :full_url, do: make_url(url_path())
      let :resp_body, do: %{"foo" => "bar"}

      let(:resp_env) do
        %Tesla.Env{
          status: 200,
          body: resp_body(),
          headers: %{"content-type": "application/json"}
        }
      end

      before do
        Cache.write full_url(), resp_env()
        # Return `nil` because `Cache.write` returns a `{:ok, value}` tuple,
        # that ESpec would interpret as an attempt to make `value` available
        # to the tests and would fail if `value` is not an enumerable.
        nil
      end

      it "returns the cached response, without executing the request" do
        expect subject() |> to(eq {:ok, resp_body()})
        # If a request was performed, this would raise an exception because
        # there is not open Bypass listening on localhost:port.
      end
    end
  end
end
