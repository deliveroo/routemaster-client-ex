defmodule Routemaster.RedisSpec do
  use ESpec
  alias Routemaster.Redis
  import Routemaster.TestUtils

  before_all do: clear_redis_test_db()
  finally do: clear_redis_test_db()

  describe "redis commands" do
    describe "GET and SET" do
      context "with strings" do
        example "reading a non present value returns nil" do
          expect Redis.get("foo") |> to(eq {:ok, nil})
        end

        it "allows to read previously set key-values" do
          expect Redis.set("foo", "bar") |> to(eq {:ok, "OK"})
          expect Redis.get("foo") |> to(eq {:ok, "bar"})
        end
      end

      context "with atoms" do
        example "reading a non present value returns nil" do
          expect Redis.get(:foo) |> to(eq {:ok, nil})
        end

        it "allows to read previously set key-values" do
          expect Redis.set(:foo, "bar") |> to(eq {:ok, "OK"})
          expect Redis.get(:foo) |> to(eq {:ok, "bar"})
        end
      end
    end


    describe "SETEX and TTL" do
      it "SETEX sets a key with an expiration TTL, in seconds" do
        expect Redis.setex(:banana, 100, "some value") |> to(eq {:ok, "OK"})
        {:ok, ttl} = Redis.ttl :banana
        expect(ttl) |> to(be_integer)
        expect(ttl) |> to(be_close_to 100, 1) # value, delta
      end

      specify "TTL returns -1 for keys without expiration" do
        {:ok, "OK"} = Redis.set(:coconut, "coconut coconut")
        expect Redis.ttl(:coconut) |> to(eq {:ok, -1})
      end
    end
  end
end
