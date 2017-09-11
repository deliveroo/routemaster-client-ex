defmodule Routemaster.Drain.EventStateSpec do
  use ESpec
  alias Routemaster.Drain.Event
  alias Routemaster.Drain.EventState
  import Routemaster.TestUtils

  before_all do: clear_redis_test_db(Routemaster.Redis.Data)
  finally do: clear_redis_test_db(Routemaster.Redis.Data)


  let :timestamp, do: now()
  let :url, do: "https://event.state.test.com/1"
  let(:event) do
    %Event{url: url(), t: timestamp(), topic: "dogs", type: "updated"}
  end


  describe "fresh?(event)" do
    subject(EventState.fresh?(event()))

    context "when there is NO previous state for that event's URL" do
      before do
        clear_redis_test_db(Routemaster.Redis.Data)
      end

      it "always returns true" do
        assert subject()
      end
    end

    context "when there is previous state for that event's URL" do
      let :previous_event, do: %{event() | t: previous_timestamp()}

      before do
        EventState.save(previous_event())
      end

      context "and the previous state is MORE recent than the current event" do
        let :previous_timestamp, do: timestamp() + 1

        it "returns false" do
          refute subject()
        end
      end

      context "and the previous state is LESS recent than the current event" do
        let :previous_timestamp, do: timestamp() - 1

        it "returns true" do
          assert subject()
        end
      end

      context "and the previous state is EQUALLY recent to the current event" do
        let :previous_timestamp, do: timestamp()

        it "returns false" do
          refute subject()
        end
      end
    end
  end


  describe "get(url)" do
    subject(EventState.get(url()))

    context "when there is NO saved state for that URL" do
      before do
        clear_redis_test_db(Routemaster.Redis.Data)
      end

      it "returns the null EventState (t == 0)" do
        expect subject() |> to(eq %EventState{url: url(), t: 0})
      end
    end

    context "when there is a saved state for that URL" do
      before do
        EventState.save(event())
      end

      it "returns the stored EventState" do
        expect subject() |> to(eq %EventState{url: event().url, t: event().t})
      end
    end
  end


  describe "save(event)" do
    it "persists EventState data for the provided Event" do
      expect EventState.get(url()) |> to(eq %EventState{url: event().url, t: 0})
      EventState.save(event())
      expect EventState.get(url()) |> to(eq %EventState{url: event().url, t: event().t})
    end
  end
end
