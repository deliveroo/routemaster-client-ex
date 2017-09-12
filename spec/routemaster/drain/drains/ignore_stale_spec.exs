defmodule Routemaster.Drains.IgnoreStaleSpec do
  use ESpec, async: false

  alias Routemaster.Drains.IgnoreStale
  alias Routemaster.Drain.Event
  alias Routemaster.Drain.EventState
  import Routemaster.TestUtils

  before_all do: clear_redis_test_db(Routemaster.Redis.Data)
  finally do: clear_redis_test_db(Routemaster.Redis.Data)

  @opts IgnoreStale.init([])

  let :shuffled_events do
    [
      %Event{url: "http://foo.bar/1", type: "noop", t: 100010},
      %Event{url: "http://foo.bar/1", type: "noop", t: 100011},

      %Event{url: "http://foo.bar/1", type: "update", t: 100020},
      %Event{url: "http://foo.bar/1", type: "update", t: 100021},
      %Event{url: "http://foo.bar/1", type: "update", t: 100022},

      %Event{url: "http://foo.bar/2", type: "update", t: 100030},
      %Event{url: "http://foo.bar/2", type: "update", t: 100031},

      %Event{url: "http://foo.bar/3", type: "noop", t: 100040},
    ]
    |> Enum.shuffle()
  end

  let :conn do
    Plug.Conn
    |> struct()
    |> Plug.Conn.assign(:events, shuffled_events())
  end

  # don't memoize this
  defp perform do
    IgnoreStale.call(conn(), @opts).assigns.events
  end


  describe "when there is no previous state or the previous state is stale" do
    before do
      clear_redis_test_db(Routemaster.Redis.Data)
    end

    it "only preserves the most recent events for each URL" do
      events = perform()

      expect events |> to(be_list())
      expect events |> to(have_length 3)

      expected_events = [
        %Event{url: "http://foo.bar/1", type: "update", t: 100022},
        %Event{url: "http://foo.bar/2", type: "update", t: 100031},
        %Event{url: "http://foo.bar/3", type: "noop", t: 100040},
      ] |> Enum.sort

      actual_events = Enum.sort(events)

      expect actual_events |> to(eq expected_events)
    end

    describe "with each pass, the state gets update with the freshest events" do
      before do
        # First call, this will write the events' timestamps in Redis.
        perform()
      end

      specify "and subsequent calls reflect the same state" do
        # Second call, at this point the timestamps are not newer than what's
        # in redis, and are therefore stale.
        events = perform()

        expect events |> to(be_list())
        expect events |> to(have_length 0)    
      end
    end
  end


  describe "when the previous state is fresher than an event" do
    before do
      clear_redis_test_db(Routemaster.Redis.Data)

      EventState.save(
        %Event{url: "http://foo.bar/1", type: "noop", t: 900000}
      )

      EventState.save(
        %Event{url: "http://foo.bar/3", type: "noop", t: 900000}
      )
    end

    it "only preserves the most recent events for each URL" do
      events = perform()

      expect events |> to(be_list())
      expect events |> to(have_length 1)

      expected_events = [
        %Event{url: "http://foo.bar/2", type: "update", t: 100031},
      ]
      expect events |> to(eq expected_events)
    end
  end
end
