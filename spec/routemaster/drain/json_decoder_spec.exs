defmodule Routemaster.Drain.JsonDecoderSpec do
  use ESpec, async: true

  import Routemaster.TestUtils

  alias Routemaster.Drain.JsonDecoder, as: Decoder
  alias Routemaster.Drain.Event

  @port 12311
  @base_url "http://localhost:#{@port}"

  describe "decode!" do
    it "decodes empty lists" do
      json = "[]"
      expect Decoder.decode!(json) |> to(eq [])
    end

    it "decodes lists with one valid element" do
      json = "[#{make_drain_event("/squirrels/1", @port)}]"
      [event | []] = Decoder.decode!(json)

      expect event |> to(be_struct Event)

      %Event{data: nil, t: timestamp, topic: "squirrels", type: "update", url: "#{@base_url}/squirrels/1"} = event
      expect timestamp |> to(be_close_to (now() - 2), 1)
    end

    it "decodes lists with two valid elements" do
      json = "[#{make_drain_event("/squirrels/1", @port)},#{make_drain_event("/squirrels/2", @port)}]"
      [e1, e2] = Decoder.decode!(json)

      expect e1 |> to(be_struct Event)
      expect e2 |> to(be_struct Event)

      # See `make_drain_event/1` for details.
      %Event{data: nil, t: t1, topic: "squirrels", type: "update", url: "#{@base_url}/squirrels/1"} = e1
      %Event{data: nil, t: t2, topic: "squirrels", type: "update", url: "#{@base_url}/squirrels/2"} = e2

      expect t1 |> to(be_close_to (now() - 2), 1)
      expect t2 |> to(be_close_to (now() - 2), 1)
    end


    describe "with invalid data" do
      alias Routemaster.Drain.JsonDecoder.InvalidPayloadError

      before do
        now = now() - 2
        bad_elements = [
          ~s({"type":"update","topic":"dinosaurs","url":"#{@base_url}/dinosaurs/1"}), # no t
          ~s({"topic":"dinosaurs","url":"#{@base_url}/dinosaurs/2","t":#{now}}), # no type
          ~s({"type":"update","url":"#{@base_url}/dinosaurs/3","t":#{now}}), # no topic
          ~s({"type":"update","topic":"dinosaurs","t":#{now}}), # no url
          ~s({"who am I?":"I am Batman!"}), # na na na na na na na na, Batman!
          ~s({}) # empty
        ]

        {:shared, bad_elements: bad_elements}
      end


      it "it raises an exception when all the data is bad" do
        json = "[#{Enum.join(shared.bad_elements, ",")}]"
        expect fn() -> Decoder.decode!(json) end |> to(raise_exception InvalidPayloadError)
      end

      it "it raises an exception when most of the data is bad" do
        json = "[#{make_drain_event("/dinosaurs/42", @port)},#{Enum.join(shared.bad_elements, ",")}]"
        expect fn() -> Decoder.decode!(json) end |> to(raise_exception InvalidPayloadError)
      end

      it "it raises an exception when a single element is bad" do
        [one_bad | _] = shared.bad_elements

        json = "[#{make_drain_event("/dinosaurs/1", @port)},#{make_drain_event("/dinosaurs/2", @port)},#{one_bad},#{make_drain_event("/dinosaurs/42", @port)}]"
        expect fn() -> Decoder.decode!(json) end |> to(raise_exception InvalidPayloadError)
      end
    end
  end
end
