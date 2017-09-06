defmodule Routemaster.RedisSpec do
  use ESpec, async: true
  alias Routemaster.Redis

  describe "serializing and deserializing data" do
    specify "serializing a term returns a binary" do
      data = Redis.serialize(%{one: "two", three: [1, 2, %{"foo" => "bar"}]})
      expect data |> to(be_binary())
    end

    describe "it is possible to convert terms to binaries and back" do
      defp test_serialization_of(term) do
        data = Redis.serialize(term)
        expect Redis.deserialize(data) |> to(eq term)
      end

      specify "with strings" do
        test_serialization_of("Hello World!")
      end

      specify "with numbers" do
        test_serialization_of(42.42)
      end

      specify "with lists" do
        test_serialization_of([1, "hello", 2, "world"])
      end

      specify "with tuples" do
        test_serialization_of({:ok, "go"})
      end

      specify "with maps" do
        test_serialization_of(%{one: "two", three: [1, 2, %{"foo" => "bar"}]})
      end

      specify "with structs" do
        test_serialization_of(%Routemaster.TestStruct{foo: "hello", bar: [1,2,3]})
      end
    end

    it "fails to deserialize an invalid data binary" do
      bogus_data = "definitely not valid Erlang term format"
      expect fn -> Redis.deserialize(bogus_data) end
      |> to(raise_exception ArgumentError)
    end
  end
end


defmodule Routemaster.RedisSharedSpec do
  use ESpec, shared: true
  import Routemaster.TestUtils

  # This is an "abstract" ESpec module, and is really meant to be
  # mixed into the concrete test modules defined at the end of the
  # file. This shared approach is required because the two Redis
  # stores implement the same API.

  before_all do: clear_all_redis_test_dbs()
  finally do: clear_redis_test_db(shared.redis)

  let :redis, do: shared.redis

  describe "redis commands" do
    describe "GET and SET" do
      context "with strings" do
        example "reading a non present value returns nil" do
          expect redis().get("foo") |> to(eq {:ok, nil})
        end

        it "allows to read previously set key-values" do
          expect redis().set("foo", "bar") |> to(eq {:ok, "OK"})
          expect redis().get("foo") |> to(eq {:ok, "bar"})
        end
      end

      context "with atoms" do
        example "reading a non present value returns nil" do
          expect redis().get(:foo) |> to(eq {:ok, nil})
        end

        it "allows to read previously set key-values" do
          expect redis().set(:foo, "bar") |> to(eq {:ok, "OK"})
          expect redis().get(:foo) |> to(eq {:ok, "bar"})
        end
      end
    end


    describe "MGET" do
      it "reads the values for a list of keys, together" do
        redis().set("one", "uno")
        redis().set("two", "due")
        redis().set("four", "quattro")

        out = redis().mget(~w(one two three four five))
        expect out |> to(eq {:ok, ["uno", "due", nil, "quattro", nil]})
      end
    end


    describe "SETEX and TTL" do
      it "SETEX sets a key with an expiration TTL, in seconds" do
        expect redis().setex(:banana, 100, "some value") |> to(eq {:ok, "OK"})
        {:ok, ttl} = redis().ttl :banana
        expect(ttl) |> to(be_integer())
        expect(ttl) |> to(be_close_to 100, 1) # value, delta
      end

      specify "TTL returns -1 for keys without expiration" do
        {:ok, "OK"} = redis().set(:coconut, "coconut coconut")
        expect redis().ttl(:coconut) |> to(eq {:ok, -1})
      end
    end


    describe "DEL" do
      describe "with a single key as argument" do
        subject(redis().del(:my_key))

        context "when the key doesn't exist" do
          before do
            {:ok, value} = redis().get(:my_key)
            expect(value) |> to(be_nil())
          end

          it "returns 0" do
            expect(subject()) |> to(eq {:ok, 0})
          end
        end

        context "when the key exists" do
          before do
            {:ok, "OK"} = redis().set(:my_key, "foobar")
            {:ok, value} = redis().get(:my_key)
            expect(value) |> to_not(be_nil())
          end

          it "deletes the key and returns 1" do
            expect(subject()) |> to(eq {:ok, 1})

            {:ok, value} = redis().get(:my_key)
            expect(value) |> to(be_nil())
          end
        end
      end

      describe "with a list of keys as argument" do
        subject(redis().del([:foo, :bar, :baz]))

        context "when all keys exist" do
          before do
            {:ok, "OK"} = redis().set(:foo, "aaa")
            {:ok, "OK"} = redis().set(:bar, "bbb")
            {:ok, "OK"} = redis().set(:baz, "ccc")

            # automatic failure reporting for failed pattern matching
            {:ok, "aaa"} = redis().get(:foo)
            {:ok, "bbb"} = redis().get(:bar)
            {:ok, "ccc"} = redis().get(:baz)
          end


          it "deletes them all and returns their count" do
            expect(subject()) |> to(eq {:ok, 3})

            # automatic failure reporting for failed pattern matching
            {:ok, nil} = redis().get(:foo)
            {:ok, nil} = redis().get(:bar)
            {:ok, nil} = redis().get(:baz)
          end
        end

        context "when only some keys exist" do
          before do
            {:ok, "OK"} = redis().set(:foo, "aaa")
            {:ok, "OK"} = redis().set(:baz, "ccc")

            # automatic failure reporting for failed pattern matching
            {:ok, "aaa"} = redis().get(:foo)
            {:ok, nil} = redis().get(:bar)
            {:ok, "ccc"} = redis().get(:baz)
          end

          it "deletes the ones that exist and returns their count" do
            expect(subject()) |> to(eq {:ok, 2})

            # automatic failure reporting for failed pattern matching
            {:ok, nil} = redis().get(:foo)
            {:ok, nil} = redis().get(:bar)
            {:ok, nil} = redis().get(:baz)
          end
        end

        context "when no keys exist" do
          it "returns 0" do
            expect(subject()) |> to(eq {:ok, 0})
          end
        end
      end
    end
  end
end


# These two modules are what actually "runs" the tests.

defmodule Routemaster.RedisDataSpec do
  use ESpec
  alias Routemaster.Redis

  doctest Routemaster.Redis

  before redis: Redis.data()
  it_behaves_like(Routemaster.RedisSharedSpec)
end

defmodule Routemaster.RedisCacheSpec do
  use ESpec
  alias Routemaster.Redis

  before redis: Redis.cache()
  it_behaves_like(Routemaster.RedisSharedSpec)
end
