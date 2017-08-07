defmodule Routemaster.Fetcher.CachingSpec do
  use ESpec

  alias Routemaster.Fetcher.Caching
  alias Routemaster.Cache

  import Routemaster.TestUtils

  before_all do: clear_redis_test_db(Routemaster.Redis.cache())
  finally do: clear_redis_test_db(Routemaster.Redis.cache())


  let :req_url, do: "https://localhost/hamsters/1"
  let :cache_enabled, do: true

  let(:req_env) do
    %Tesla.Env{
      url: req_url(),
      headers: %{"accept": "application/json"},
      opts: [cache: cache_enabled()]
    }
  end


  let :resp_status, do: 200
  let :resp_body, do: %{"foo" => "I am a live HTTP response body"}

  let(:resp_env) do
    %Tesla.Env{
      status: resp_status(),
      body: resp_body(),
      headers: %{"content-type": "application/json"}
    }
  end

  # The next element of the Tesla stack. It represents an HTTP request.
  let :terminator do
    {:fn, fn(_env) -> resp_env() end}
  end


  subject Caching.call(req_env(), [terminator()], nil)


  context "when the cache layer is enabled in the request struct" do
    let :cache_enabled, do: true

    describe "when there is no cached value" do
      before do
        clear_redis_test_db(Routemaster.Redis.cache())
      end

      describe "for successful responses" do
        let :resp_status, do: 200

        it "executes the HTTP request and returns the response" do
          expect subject() |> to(eq resp_env())
        end

        it "caches the response" do
          expect Cache.read(req_url()) |> to(eq {:miss, nil})
          subject()
          expect Cache.read(req_url()) |> to(eq {:ok, resp_env()})
        end

        describe "successive requests" do
          let :original_response, do: resp_env()

          before do
            # execute one request to cache the first response
            subject()
            expect Cache.read(req_url()) |> to(eq {:ok, original_response()})
          end

          specify "don't execute the HTTP request again, and just use the cached value" do
            # don't declare this in a `let` because it would break the `before` block
            new_terminator = {:fn, fn(_env) ->
              raise "Test Error: HTTP request was executed when simple cache hit was expected."
            end}
            second_request = fn() -> Caching.call(req_env(), [new_terminator], nil) end

            expect(second_request.()) |> to(eq original_response())
          end
        end
      end

      describe "for NON successful responses" do
        let :resp_status, do: 404

        it "executes the HTTP request and returns the response" do
          expect subject() |> to(eq resp_env())
          expect subject().status |> to(eq 404) # just to be explicit
        end

        it "does NOT cache the response" do
          expect Cache.read(req_url()) |> to(eq {:miss, nil})
          subject()
          expect Cache.read(req_url()) |> to(eq {:miss, nil})
        end

        describe "successive requests" do
          let :original_response, do: resp_env()

          before do
            # execute one request first
            subject()
          end

          specify "will execute the HTTP request again" do
            err_msg = "Test Error: the HTTP request is being executed again. This is fine."
            new_terminator = {:fn, fn(_env) -> raise err_msg end}
            another_request = fn() -> Caching.call(req_env(), [new_terminator], nil) end

            expect another_request |> to(raise_exception RuntimeError, err_msg)
            expect another_request |> to(raise_exception RuntimeError, err_msg)
          end
        end
      end
    end


    describe "when there is a cached response for the URL" do
      let(:cached_resp_env) do
        %{resp_env() | body: %{"foo" => "I'm cached!"}}
      end

      let :terminator do
        {:fn, fn(_env) ->
          raise "Test Error: HTTP request was executed when simple cache hit was expected."
        end}
      end

      before do
        Cache.write req_url(), cached_resp_env()
        # Return `nil` because `Cache.write` returns a `{:ok, value}` tuple,
        # that ESpec would interpret as an attempt to make `value` available
        # to the tests and would fail if `value` is not an enumerable.
        nil
      end

      it "returns the cached response" do
        expect subject() |> to(eq cached_resp_env())
      end

      it "doesn't execute any HTTP request" do
        expect fn -> subject() end |> to_not(raise_exception())
      end
    end
  end


  context "when the cache layer is disabled in the request struct" do
    let :cache_enabled, do: false

    it "executes the HTTP request and returns the response" do
      expect subject() |> to(eq resp_env())
    end

    it "does NOT update the cache" do
      expect Cache.read(req_url()) |> to(eq {:miss, nil})
      subject()
      expect Cache.read(req_url()) |> to(eq {:miss, nil})
    end

    describe "when there is a cached response for the URL" do
      let(:cached_resp_env) do
        %{resp_env() | body: %{"foo" => "I'm cached!"}}
      end

      before do
        Cache.write req_url(), cached_resp_env()
        # Return `nil` because `Cache.write` returns a `{:ok, value}` tuple,
        # that ESpec would interpret as an attempt to make `value` available
        # to the tests and would fail if `value` is not an enumerable.
        nil
      end

      it "ignores the cached value and executes the HTTP request" do
        expect subject() |> to(eq resp_env())
      end
    end
  end
end
