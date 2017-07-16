defmodule Routemaster.PublisherSpec do
  use ESpec
  import Routemaster.TestUtils

  alias Routemaster.Publisher
  alias Plug.Conn

  let :frozen_time, do: now()

  before do
    allow Routemaster.Utils |> to(accept :now, fn() -> frozen_time() end)
    bypass = Bypass.open(port: 4567)
    {:shared, bypass: bypass}
  end

  finally do
    Bypass.verify_expectations!(shared.bypass)
  end

  @topic "hamsters"
  @url "https://foo.bar/1"
  @data %{"foo" => "bar"}

  describe "send_event()" do
    it "sets the correct user-agent HTTP header" do
      Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn conn ->
        [ua|[]] = Conn.get_req_header conn, "user-agent"
        expect ua |> to(start_with "routemaster-client-ex-v")

        Conn.resp(conn, 200, "")
      end

      Publisher.send_event(@topic, "noop", @url)
    end

    context "argument errors" do
      @error_type Routemaster.Publisher.Event.ValidationError

      describe "with an invalid URL" do
        it "raises an exception" do
          expect fn() -> Publisher.send_event(@topic, "noop", "http://foo.bar/1") end
          |> to(raise_exception @error_type)
        end
      end

      describe "with an invalid timestamp" do
        it "raises an exception" do
          expect fn() -> Publisher.send_event(@topic, "noop", @url, timestamp: "not valid") end
          |> to(raise_exception @error_type)
        end
      end
    end

    context "with valid arguments" do
      describe "the return value" do
        before do
          response_status = status()
          Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn(conn) ->
            Conn.resp(conn, response_status, "")
          end
        end

        context "with a NON successful request" do
          let :status, do: 400

          it "returns {:error, http_status}" do
            expect Publisher.send_event(@topic, "noop", @url) |> to(eq {:error, 400})
          end
        end

        context "with a successful request" do
          let :status, do: 200

          it "returns :ok" do
            expect Publisher.send_event(@topic, "noop", @url) |> to(eq :ok)
          end
        end
      end
    end

    describe "the submitted payload" do
      let :status, do: 200

      describe "when only the type and url are specified" do
        subject(Publisher.send_event(@topic, "noop", @url))

        it "sends the event type, the url and automatically sets a timestamp" do
          time = frozen_time()
          Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn(conn) ->
            payload = request_payload(conn)

            expect payload["type"]      |> to(eq "noop")
            expect payload["url"]       |> to(eq @url)
            expect payload["timestamp"] |> to(eq time)
            expect payload["data"]      |> to(be_nil())

            Conn.resp(conn, 200, "")
          end

          subject()
        end
      end

      describe "when type, url, and a timestamp are specified" do
        subject(Publisher.send_event(@topic, "noop", @url, timestamp: 12345))

        it "sends the event type, the url and the timestamp" do
          Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn(conn) ->
            payload = request_payload(conn)

            expect payload["type"]      |> to(eq "noop")
            expect payload["url"]       |> to(eq @url)
            expect payload["timestamp"] |> to(eq 12345)
            expect payload["data"]      |> to(be_nil())

            Conn.resp(conn, 200, "")
          end

          subject()
        end
      end

      describe "when type, url, and a data payload are specified" do
        let :data_payload, do: %{"foo" => "bar", "baz" => [1, 2, 3], "qwe" => %{"rty" => "hello"}}
        subject(Publisher.send_event(@topic, "noop", @url, data: data_payload()))

        it "sends the event type, the url, the data, and automatically sets a timestamp" do
          time = frozen_time()
          data = data_payload()
          Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn(conn) ->
            payload = request_payload(conn)

            expect payload["type"]      |> to(eq "noop")
            expect payload["url"]       |> to(eq @url)
            expect payload["timestamp"] |> to(eq time)
            expect payload["data"]      |> to(eq data)

            Conn.resp(conn, 200, "")
          end

          subject()
        end
      end

      describe "when type, url, timestamp and a data payload are specified" do
        let :data_payload, do: %{"foo" => "bar", "baz" => [1, 2, 3], "qwe" => %{"rty" => "hello"}}
        subject(Publisher.send_event(@topic, "noop", @url, timestamp: 12345, data: data_payload()))

        it "sends the event type, the url, the timestamp and the data" do
          data = data_payload()
          Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn(conn) ->
            payload = request_payload(conn)

            expect payload["type"]      |> to(eq "noop")
            expect payload["url"]       |> to(eq @url)
            expect payload["timestamp"] |> to(eq 12345)
            expect payload["data"]      |> to(eq data)

            Conn.resp(conn, 200, "")
          end

          subject()
        end
      end
    end
  end


  describe "create()" do
    subject(Publisher.create(@topic, "#{@url}/a", timestamp: 11111, data: @data))

    it "sends a create event" do
      Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn(conn) ->
        payload = request_payload(conn)

        expect payload["type"]      |> to(eq "create")
        expect payload["url"]       |> to(eq "#{@url}/a")
        expect payload["timestamp"] |> to(eq 11111)
        expect payload["data"]      |> to(eq @data)

        Conn.resp(conn, 200, "")
      end

      subject()
    end
  end


  describe "update()" do
    subject(Publisher.update(@topic, "#{@url}/b", timestamp: 22222, data: @data))

    it "sends an update event" do
      Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn(conn) ->
        payload = request_payload(conn)

        expect payload["type"]      |> to(eq "update")
        expect payload["url"]       |> to(eq "#{@url}/b")
        expect payload["timestamp"] |> to(eq 22222)
        expect payload["data"]      |> to(eq @data)

        Conn.resp(conn, 200, "")
      end

      subject()
    end
  end


  describe "delete()" do
    subject(Publisher.delete(@topic, "#{@url}/c", timestamp: 33333, data: @data))

    it "sends a delete event" do
      Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn(conn) ->
        payload = request_payload(conn)

        expect payload["type"]      |> to(eq "delete")
        expect payload["url"]       |> to(eq "#{@url}/c")
        expect payload["timestamp"] |> to(eq 33333)
        expect payload["data"]      |> to(eq @data)

        Conn.resp(conn, 200, "")
      end

      subject()
    end
  end


  describe "noop()" do
    subject(Publisher.noop(@topic, "#{@url}/d", timestamp: 44444, data: @data))

    it "sends a noop event" do
      Bypass.expect_once shared.bypass, "POST", "/topics/#{@topic}", fn(conn) ->
        payload = request_payload(conn)

        expect payload["type"]      |> to(eq "noop")
        expect payload["url"]       |> to(eq "#{@url}/d")
        expect payload["timestamp"] |> to(eq 44444)
        expect payload["data"]      |> to(eq @data)

        Conn.resp(conn, 200, "")
      end

      subject()
    end
  end
end
