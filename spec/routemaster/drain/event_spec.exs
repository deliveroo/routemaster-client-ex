defmodule Routemaster.Drain.EventSpec do
  use ESpec, async: true
  alias Routemaster.Drain.Event
  import Routemaster.TestUtils

  describe "complete?(event)" do
    it "returns true with an event with all the mandatory attributes" do
      event = %Event{type: "noop", url: "https://bla.com/1", t: now(), topic: "dogs"}
      assert Event.complete?(event)
    end

    it "returns false with an event that lacks a mandatory attribute" do
      event = %Event{url: "https://bla.com/1", t: now(), topic: "dogs"}
      refute Event.complete?(event)

      event = %Event{type: "noop", t: now(), topic: "dogs"}
      refute Event.complete?(event)

      event = %Event{type: "noop", url: "https://bla.com/1", topic: "dogs"}
      refute Event.complete?(event)

      event = %Event{type: "noop", url: "https://bla.com/1", t: now()}
      refute Event.complete?(event)
    end
  end
end
