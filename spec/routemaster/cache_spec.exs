defmodule Routemaster.CacheSpec do
  use ESpec
  alias Routemaster.Cache
  import Routemaster.TestUtils

  before_all do: clear_redis_test_db()
  finally do: clear_redis_test_db()

  describe "reading and writing" do
    describe "read(key)" do
      
    end

    describe "write(key, term)" do
      
    end
  end

  describe "fetching with a fallback function" do
    
  end

  describe "clearing a key" do
    
  end
end
