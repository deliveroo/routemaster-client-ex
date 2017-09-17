defmodule Routemaster.Drains.SiphonSpec do
  use ESpec, async: false

  alias Routemaster.Drains.Siphon
  alias Routemaster.Drain.Event

  defmodule TestSiphon do
    def call(_events) do
      raise "always stub me please"
    end
  end

  before do
    allow(TestSiphon).to accept(:call, fn(_siphoned_events) -> nil end)
  end

  let :shuffled_events do
    [
      %Event{url: "http://tex.mex/burritos/1", topic: "burritos"},
      %Event{url: "http://tex.mex/burritos/2", topic: "burritos"},
      %Event{url: "http://tex.mex/burritos/3", topic: "burritos"},

      %Event{url: "http://tex.mex/chimichangas/1", topic: "chimichangas"},
      %Event{url: "http://tex.mex/chimichangas/2", topic: "chimichangas"},

      %Event{url: "http://tex.mex/enchiladas/1", topic: "enchiladas"},
      %Event{url: "http://tex.mex/enchiladas/2", topic: "enchiladas"},
      %Event{url: "http://tex.mex/enchiladas/3", topic: "enchiladas"},
    ]
    |> Enum.shuffle()
  end

  let :conn do
    Plug.Conn
    |> struct()
    |> Plug.Conn.assign(:events, shuffled_events())
  end

  defp perform do
    out_conn = Siphon.call(conn(), Siphon.init(options()))
    :timer.sleep(50)
    out_conn
  end


  # ESpec provides a function to expect that a stubbed function is called
  # with some arguments, but it doesn't really let to control the received
  # arguments before the assertion, so it fails when working with lists
  # with randomly sorted items (like in this case).
  #
  # Setting expectations inside the `allow(target).to accept(:call, fn...)`
  # function would normally work, but since in this case it's called in an
  # async Task, it raises all sorts of weird exceptions instead of just
  # failing the test with a pretty failure message.
  #
  # Since ESpec mocks are built on Erlang's meck, and the previously
  # mentiond `accepted` verifiying expectation is a layer around
  # `:meck.history`, we can easy build our own helper.
  #
  defp retrieve_siphoned_events(siphon) do
    case :meck.history(siphon) do
      [] ->
        # the siphon.call/1 function was not called at all
        :siphon_not_called
      [{_pid, {^siphon, :call, [received_events]}, _return_value} | []] ->
        # the siphon.call/1 function was called with these events
        received_events
    end
  end


  describe "with a single topic" do
    let(:options) do
      [topic: "chimichangas", to: TestSiphon]
    end

    let(:matching_events) do
      Enum.sort([
        %Event{url: "http://tex.mex/chimichangas/1", topic: "chimichangas"},
        %Event{url: "http://tex.mex/chimichangas/2", topic: "chimichangas"},
      ])
    end

    it "returns a Plug.Conn" do
      conn = perform()
      expect conn |> to(be_struct Plug.Conn)
    end

    it "sends the matching events to the siphon module" do
      perform()
      siphoned_events = retrieve_siphoned_events(TestSiphon)

      expect siphoned_events |> to(be_list())
      expect Enum.sort(siphoned_events) |> to(eql matching_events())
    end


    it "removes the matching events from the conn.assigns" do
      conn = perform()
      remanining_events = conn.assigns.events

      expect remanining_events |> to(be_list())
      expect remanining_events |> to(have_length 6)

      Enum.each matching_events(), fn(matching_event) ->
        expect remanining_events |> to_not(have matching_event)
      end
    end


    context "when no events match the topic" do
      let(:options) do
        [topic: "springrolls", to: TestSiphon]
      end

      it "returns a Plug.Conn" do
        conn = perform()
        expect conn |> to(be_struct Plug.Conn)
      end

      it "doesn't invoke the call function on the siphon module" do
        perform()
        siphoned_events = retrieve_siphoned_events(TestSiphon)

        expect siphoned_events |> to(eql :siphon_not_called)
      end

      it "doesn't remove any events from the conn.assigns" do
        conn = perform()
        remanining_events = conn.assigns.events

        expect remanining_events |> to(be_list())

        expect Enum.sort(remanining_events) |> to(eql Enum.sort(shuffled_events()))
      end
    end
  end


  describe "with multiple topics" do
    let(:options) do
      [topics: ~w(burritos chimichangas), to: TestSiphon]
    end

    let(:matching_events) do
      Enum.sort([
        %Event{url: "http://tex.mex/burritos/1", topic: "burritos"},
        %Event{url: "http://tex.mex/burritos/2", topic: "burritos"},
        %Event{url: "http://tex.mex/burritos/3", topic: "burritos"},
        %Event{url: "http://tex.mex/chimichangas/1", topic: "chimichangas"},
        %Event{url: "http://tex.mex/chimichangas/2", topic: "chimichangas"},
      ])
    end

    it "returns a Plug.Conn" do
      conn = perform()
      expect conn |> to(be_struct Plug.Conn)
    end

    it "sends the matching events to the siphon module" do
      perform()
      siphoned_events = retrieve_siphoned_events(TestSiphon)

      expect siphoned_events |> to(be_list())
      expect Enum.sort(siphoned_events) |> to(eql matching_events())
    end


    it "removes the matching events from the conn.assigns" do
      conn = perform()
      remanining_events = conn.assigns.events

      expect remanining_events |> to(be_list())
      expect remanining_events |> to(have_length 3)

      Enum.each matching_events(), fn(matching_event) ->
        expect remanining_events |> to_not(have matching_event)
      end
    end


    context "when no events match the topic" do
      let(:options) do
        [topics: ~w(springrolls dumplings), to: TestSiphon]
      end

      it "returns a Plug.Conn" do
        conn = perform()
        expect conn |> to(be_struct Plug.Conn)
      end

      it "doesn't invoke the call function on the siphon module" do
        perform()
        siphoned_events = retrieve_siphoned_events(TestSiphon)

        expect siphoned_events |> to(eql :siphon_not_called)
      end

      it "doesn't remove any events from the conn.assigns" do
        conn = perform()
        remanining_events = conn.assigns.events

        expect remanining_events |> to(be_list())

        expect Enum.sort(remanining_events) |> to(eql Enum.sort(shuffled_events()))
      end
    end
  end


  describe "configuration failures" do
    specify "without a siphon option it raises a KeyError" do
      expect fn()-> Siphon.init(topic: "food") end
      |> to(raise_exception KeyError)
    end

    specify "without a topic or topics option it raises a KeyError" do
      expect fn()-> Siphon.init(to: TestSiphon) end
      |> to(raise_exception KeyError)
    end
  end
end
