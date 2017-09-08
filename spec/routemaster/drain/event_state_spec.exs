defmodule Routemaster.Drain.EventStateSpec do
  use ESpec
  alias Routemaster.Drain.Event
  alias Routemaster.Drain.EventState
  import Routemaster.TestUtils

  before_all do: clear_redis_test_db(Routemaster.Redis.Data)
  finally do: clear_redis_test_db(Routemaster.Redis.Data)

  describe "fresh?(event)" do
    
  end


  describe "get(url)" do
    
  end


  describe "save(event)" do
    
  end
end
