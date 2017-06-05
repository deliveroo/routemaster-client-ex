defmodule Routemaster.CacheSpec do
  use ESpec
  alias Routemaster.Cache
  import Routemaster.TestUtils

  before_all do: clear_redis_test_db()
  finally do: clear_redis_test_db()

  describe "reading and writing" do
    describe "read(key)" do
      example "reading non existing keys returns {:miss, nil}" do
        expect Cache.read(:pear) |> to(eq {:miss, nil})
      end

      example "reading existing keys returns {:ok, term}" do
        Cache.write(:apple, "foobar")
        expect Cache.read(:apple) |> to(eq {:ok, "foobar"})
      end
    end

    describe "write(key, term)" do
      it "writes a key-value and returns {:ok, value}" do
        expect Cache.write(:pineapple, "ananas") |> to(eq {:ok, "ananas"})
        expect Cache.read(:pineapple) |> to(eq {:ok, "ananas"})
      end
    end


    describe "with different types of value" do
      defp test_cache_with(term, a_key \\ :a_key) do
        expect Cache.read(a_key)        |> to(eq {:miss, nil})
        expect Cache.write(a_key, term) |> to(eq {:ok, term})
        expect Cache.read(a_key)        |> to(eq {:ok, term})
      end

      it "supports binaries" do
        test_cache_with("")
        test_cache_with("  ", :another_key)
        test_cache_with("a String", :yet_another_key)
      end

      it "supports atoms" do
        test_cache_with(:hullo)
      end

      it "supports numbers" do
        test_cache_with(42)
        test_cache_with(13.37, :another_key)
      end

      it "supports booleans" do
        test_cache_with(true)
      end

      it "supports tuples" do
        test_cache_with({})
        test_cache_with({:ok, 1, "hello"}, :another_key)
      end

      it "supports lists" do
        test_cache_with([])
        test_cache_with([1,2,3], :another_key)
        test_cache_with([foo: "bar", baz: "qwe"], :yet_another_key)
      end

      it "supports maps" do
        test_cache_with(%{foo: "bar", baz: [1,2,3]})
        test_cache_with(%{"aaa" => "bbb", [1] => {:ok}}, :another_key)
        test_cache_with(%{}, :yet_another_key)
      end

      it "supports structs" do
        test_cache_with(%Routemaster.TestStruct{foo: "hello", bar: [1,2,3]})
      end
    end
  end


  describe "fetching with a fallback function" do
    context "when there is already a cached value for that key" do
      before do
        term = "Hello Fallbacks!"
        {:ok, ^term} = Cache.write(:avocado, term)
        {:shared, term: term}
      end

      it "ignores the fallback function and returns the existing value" do
        expect(
          Cache.fetch(:avocado, fn() -> "something else" end)
        ).to eq({:ok, shared.term})
      end
    end

    context "when there is no cached value for that key" do
      before do
        {:miss, nil} = Cache.read(:mango)
      end

      it "executes the fallback and caches and returns the result" do
        expect(
          Cache.fetch(:mango, fn() -> "I am set" <> " dynamically!" end)
        ).to eq({:ok, "I am set dynamically!"})

        expect Cache.read(:mango) |> to(eq {:ok, "I am set dynamically!"})
      end
    end
  end


  describe "clearing a key" do
    context "for existing keys" do
      before do
        {:ok, "hello"} = Cache.write(:hello, "hello")        
      end

      it "removes that key-value pair from the cache and returns :ok" do
        expect Cache.read(:hello) |> to(eq {:ok, "hello"})
        expect Cache.clear(:hello) |> to(eq :ok)
        expect Cache.read(:hello) |> to(eq {:miss, nil})
      end
    end

    context "for non existing keys" do
      it "is a no-op but it still returns :ok" do
        expect Cache.read(:hello) |> to(eq {:miss, nil})
        expect Cache.clear(:hello) |> to(eq :ok)
        expect Cache.read(:hello) |> to(eq {:miss, nil})
      end
    end
  end
end
