defmodule Routemaster.Publisher.EventSpec do
  use ESpec, async: false
  alias Routemaster.Publisher.Event
  import Routemaster.TestUtils

  @ev_type "noop"
  @url "https://foo.bar/1"


  describe "build() returns an event Map, and the timestamp is always set" do
    let :frozen_time, do: now()
    before do
      allow Routemaster.Utils |> to(accept :now, fn() -> frozen_time() end)
    end

    specify "with only type and url" do
      expect Event.build(@ev_type, @url, nil, nil)
      |> to(eq %{type: @ev_type, url: @url, timestamp: frozen_time()})
    end

    specify "with type, url and timestamp" do
      t = now()
      expect Event.build(@ev_type, @url, t, nil)
      |> to(eq %{type: @ev_type, url: @url, timestamp: t})
    end

    specify "with type, url and data" do
      data = %{"foo" => "bar"}
      expect Event.build(@ev_type, @url, nil, data)
      |> to(eq %{type: @ev_type, url: @url, timestamp: frozen_time(), data: data})
    end

    specify "with type, url, timestamp and data" do
      t = now()
      data = %{"foo" => "bar"}
      expect Event.build(@ev_type, @url, t, data)
      |> to(eq %{type: @ev_type, url: @url, timestamp: t, data: data})
    end
  end


  describe "validate!" do
    @error_type Routemaster.Publisher.Event.ValidationError

    it "raises an exception if the url is not a valid HTTPS URL" do
      e = Event.build(@ev_type, "http://foo.bar/1", now(), nil)

      expect fn() -> Event.validate!(e) end
      |> to(raise_exception @error_type, ~s{invalid url: "http://foo.bar/1".})
    end

    it "raises and exception if the timestamp is not an integer" do
      e = Event.build(@ev_type, @url, "ops", nil)

      expect fn() -> Event.validate!(e) end
      |> to(raise_exception @error_type, ~s{invalid timestamp: "ops".})
    end
  end
end
