defmodule Routemaster.Drains.SharedNotifySpec do
  use ESpec, shared: true, async: false

  alias Routemaster.Drains.Notify
  alias Routemaster.Drain.Event

  defmodule TestListenerA do
    def call(_events) do
      raise "always stub me please"
    end
  end

  defmodule TestListenerB do
    def call(_events) do
      raise "always stub me please"
    end
  end

  before do
    allow(TestListenerA).to accept(:call, fn(_events) -> nil end)
    allow(TestListenerB).to accept(:call, fn(_events) -> nil end)
  end

  
  let_overridable [:shuffled_events, :matching_events]
  let_overridable topic_options: []

  let :conn do
    Plug.Conn
    |> struct()
    |> Plug.Conn.assign(:events, shuffled_events())
  end


  defp perform do
    out_conn = Notify.call(conn(), Notify.init(options()))
    :timer.sleep(50)
    out_conn
  end


  # See comment to similar method in siphon_spec.exs for more info.
  #
  defp retrieve_forwarded_events(listener) do
    case :meck.history(listener) do
      [] ->
        # the listener.call/1 function was not called at all
        :listener_not_called
      [{_pid, {^listener, :call, [received_events]}, _return_value} | []] ->
        # the listener.call/1 function was called with these events
        received_events
    end
  end


  context "with a single listener" do
    let(:options) do
      [listener: TestListenerA] ++ topic_options()
    end

    it "returns a Plug.Conn" do
      conn = perform()
      expect conn |> to(be_struct Plug.Conn)
    end

    it "sends all events to the listener module" do
      perform()
      forwarded_events = retrieve_forwarded_events(TestListenerA)

      expect forwarded_events |> to(be_list())
      expect Enum.sort(forwarded_events) |> to(eql matching_events())

      # Obviously, a non-configured listener won't receive events.
      # This is here mainly to fail if the test setup gets messed up
      forwarded_events_b = retrieve_forwarded_events(TestListenerB)
      expect forwarded_events_b |> to(eql :listener_not_called)
    end

    describe "when there are no events in payload (e.g. a previous siphon has removed them all)" do
      let :shuffled_events, do: []

      it "returns a Plug.Conn" do
        conn = perform()
        expect conn |> to(be_struct Plug.Conn)
      end

      it "doesn't invoke the call function of the listener module" do
        perform()
        forwarded_events = retrieve_forwarded_events(TestListenerA)

        expect forwarded_events |> to(eql :listener_not_called)
      end
    end
  end

  context "with multiple listeners" do
    let(:options) do
      [listeners: [TestListenerA, TestListenerB]] ++ topic_options()
    end

    it "returns a Plug.Conn" do
      conn = perform()
      expect conn |> to(be_struct Plug.Conn)
    end

    it "sends all events to the all listener modules" do
      perform()
      forwarded_events_a = retrieve_forwarded_events(TestListenerA)
      forwarded_events_b = retrieve_forwarded_events(TestListenerB)

      expect forwarded_events_a |> to(eql forwarded_events_b)

      expect forwarded_events_a |> to(be_list())
      expect Enum.sort(forwarded_events_a) |> to(eql matching_events())

      expect forwarded_events_b |> to(be_list())
      expect Enum.sort(forwarded_events_b) |> to(eql matching_events())
    end

    describe "when there are no events in payload (e.g. a previous siphon has removed them all)" do
      let :shuffled_events, do: []

      it "returns a Plug.Conn" do
        conn = perform()
        expect conn |> to(be_struct Plug.Conn)
      end

      it "doesn't invoke the call function of any listener module" do
        perform()
        forwarded_events_a = retrieve_forwarded_events(TestListenerA)
        forwarded_events_b = retrieve_forwarded_events(TestListenerB)

        expect forwarded_events_a |> to(eql :listener_not_called)
        expect forwarded_events_b |> to(eql :listener_not_called)
      end
    end
  end
end


defmodule Routemaster.Drains.NotifySpec do
  use ESpec, async: false

  alias Routemaster.Drains.Notify
  alias Routemaster.Drain.Event

  describe "event notifications and topic filters" do
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


    describe "when listening to all topics" do
      let :matching_events, do: Enum.sort(shuffled_events())

      it_behaves_like(Routemaster.Drains.SharedNotifySpec)
    end


    describe "when listening to a single topic" do
      let :topic_options, do: [only: "chimichangas"]
      let :matching_events do
        Enum.sort([
          %Event{url: "http://tex.mex/chimichangas/1", topic: "chimichangas"},
          %Event{url: "http://tex.mex/chimichangas/2", topic: "chimichangas"},
        ])
      end

      it_behaves_like(Routemaster.Drains.SharedNotifySpec)
    end


    describe "when listening to multiple topics" do
      let :topic_options, do: [only: ~w(chimichangas burritos)]
      let :matching_events do
        Enum.sort([
          %Event{url: "http://tex.mex/burritos/1", topic: "burritos"},
          %Event{url: "http://tex.mex/burritos/2", topic: "burritos"},
          %Event{url: "http://tex.mex/burritos/3", topic: "burritos"},
          %Event{url: "http://tex.mex/chimichangas/1", topic: "chimichangas"},
          %Event{url: "http://tex.mex/chimichangas/2", topic: "chimichangas"},
        ])
      end

      it_behaves_like(Routemaster.Drains.SharedNotifySpec)
    end


    describe "when excluding a single topic" do
      let :topic_options, do: [except: "chimichangas"]
      let :matching_events do
        Enum.sort([
          %Event{url: "http://tex.mex/burritos/1", topic: "burritos"},
          %Event{url: "http://tex.mex/burritos/2", topic: "burritos"},
          %Event{url: "http://tex.mex/burritos/3", topic: "burritos"},
          %Event{url: "http://tex.mex/enchiladas/1", topic: "enchiladas"},
          %Event{url: "http://tex.mex/enchiladas/2", topic: "enchiladas"},
          %Event{url: "http://tex.mex/enchiladas/3", topic: "enchiladas"},
        ])
      end

      it_behaves_like(Routemaster.Drains.SharedNotifySpec)
    end


    describe "when listening to multiple topics" do
      let :topic_options, do: [except: ~w(chimichangas burritos)]
      let :matching_events do
        Enum.sort([
          %Event{url: "http://tex.mex/enchiladas/1", topic: "enchiladas"},
          %Event{url: "http://tex.mex/enchiladas/2", topic: "enchiladas"},
          %Event{url: "http://tex.mex/enchiladas/3", topic: "enchiladas"},
        ])
      end

      it_behaves_like(Routemaster.Drains.SharedNotifySpec)
    end
  end



  describe "initialization and configuration failures" do
    specify "without a listener option it raises a KeyError" do
      expect fn()-> Notify.init(only: "food") end
      |> to(raise_exception KeyError)

      expect fn()-> Notify.init(except: "food") end
      |> to(raise_exception KeyError)
    end

    specify "without a only or except option it defaults listen to all topics" do
      opts = Notify.init(listener: :fake_module_a)
      expect opts |> to(eql [listeners: [:fake_module_a], filter: :all])

      opts = Notify.init(listeners: [:fake_module_a, :fake_module_b])
      expect opts |> to(eql [listeners: [:fake_module_a, :fake_module_b], filter: :all])
    end
  end
end
