defmodule Routemaster.RedisSpec do
  use ESpec
  alias Routemaster.Redis
  import Routemaster.TestUtils

  before_all do: clear_redis_test_db()
  finally do: clear_redis_test_db()

  describe "redis commands" do
    describe "get and set" do
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
  end
end
