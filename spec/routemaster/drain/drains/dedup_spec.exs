defmodule Routemaster.Drains.DedupSpec do
  use ESpec, async: true

  alias Routemaster.Drains.Dedup
  alias Routemaster.Drain.Event

  @opts Dedup.init([])

  let :shuffled_events do
    [
      %Event{url: "http://foo.bar/1", type: "update", t: 12345678},
      %Event{url: "http://foo.bar/1", type: "update", t: 12345679},
      %Event{url: "http://foo.bar/1", type: "update", t: 12345680},

      %Event{url: "http://foo.bar/1", type: "noop", t: 12347777},
      %Event{url: "http://foo.bar/1", type: "noop", t: 12348000},

      %Event{url: "http://foo.bar/2", type: "update", t: 12345222},
      %Event{url: "http://foo.bar/2", type: "update", t: 12345223},

      %Event{url: "http://foo.bar/3", type: "noop", t: 12345333},
    ]
    |> Enum.shuffle()
  end

  let :conn do
    Plug.Conn
    |> struct()
    |> Plug.Conn.assign(:events, shuffled_events())
  end

  subject(
    Dedup.call(conn(), @opts).assigns.events
  )


  it "removes duplicates by :url and :type" do
    events = subject()

    expect events |> to(be_list())
    expect events |> to(have_length 4)

    expected_groups = [
      {"http://foo.bar/1", "update"},
      {"http://foo.bar/1", "noop"},
      {"http://foo.bar/2", "update"},
      {"http://foo.bar/3", "noop"},
    ] |> Enum.sort
    actual_groups = Enum.map(events, &{&1.url, &1.type}) |> Enum.sort

    expect actual_groups |> to(eq expected_groups)
  end


  specify "for each group, only the most recent event is included" do
    actual_events = subject() |> Enum.sort
    expected_events = [
      %Event{url: "http://foo.bar/1", type: "update", t: 12345680},
      %Event{url: "http://foo.bar/1", type: "noop", t: 12348000},
      %Event{url: "http://foo.bar/2", type: "update", t: 12345223},
      %Event{url: "http://foo.bar/3", type: "noop", t: 12345333},
    ] |> Enum.sort

    expect actual_events |> to(eq expected_events)
  end
end
