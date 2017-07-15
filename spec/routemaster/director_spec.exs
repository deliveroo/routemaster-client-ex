defmodule Routemaster.DirectorSpec do
  use ESpec
  import Routemaster.TestUtils

  alias Routemaster.Director
  alias Routemaster.Config
  alias Plug.Conn

  before do
    bypass = Bypass.open(port: 4567)
    {:shared, bypass: bypass}
  end

  finally do
    Bypass.verify_expectations!(shared.bypass)
  end

  it "sets the correct user-agent HTTP header" do
    Bypass.expect_once shared.bypass, "GET", "/topics", fn conn ->
      [ua|[]] = Plug.Conn.get_req_header conn, "user-agent"
      expect ua |> to(start_with "routemaster-client-ex-v")

      conn
      |> Conn.resp(200, "[]")
      |> Conn.put_resp_content_type("application/json")
    end

    Director.all_topics() # just use any of the functions
  end


  describe "all_topics() GETs a list of topics" do
    subject(Director.all_topics())

    before do
      response_status = status()
      response_body = raw_body()
      Bypass.expect_once shared.bypass, "GET", "/topics", fn conn ->
        conn
        |> Conn.resp(response_status, response_body)
        |> Conn.put_resp_content_type("application/json")
      end
    end

    context "with a successful response" do
      let :status, do: 200
      let :raw_body do
        compact_string ~s<
          [
            {"name":"topic_one","publisher":"some-service--uuid","events":123456},
            {"name":"topic_two","publisher":"another-service--uuid","events":42}
          ]
        >
      end

      let :parsed_body do
        [
          %{"events" => 123456, "name" => "topic_one", "publisher" => "some-service--uuid"},
          %{"events" => 42, "name" => "topic_two", "publisher" => "another-service--uuid"}
        ]
      end

      it "returns a list of maps for a successful response" do
        {:ok, topics} = subject()
        expect topics |> to(eq parsed_body())
      end
    end

    context "with a NON successful response" do
      let :raw_body, do: ""

      describe "HTTP 400" do
        let :status, do: 400

        it "returns an error with the HTTP status code" do
          expect subject() |> to(eq {:error, 400})
        end
      end

      describe "HTTP 500" do
        let :status, do: 500

        it "returns an error with the HTTP status code" do
          expect subject() |> to(eq {:error, 500})
        end
      end
    end
  end


  describe "get_topic() returns a single topic" do
    describe "with an invalid topic name" do
      it "raises an exception" do
        expect fn() -> Director.get_topic("foo bar") end
        |> to(raise_exception Routemaster.Topic.InvalidNameError)
      end
    end

    describe "with a valid topic name" do
      before do
        response_status = status()
        response_body = raw_body()
        Bypass.expect_once shared.bypass, "GET", "/topics", fn conn ->
          conn
          |> Conn.resp(response_status, response_body)
          |> Conn.put_resp_content_type("application/json")
        end
      end

      context "with a successful response" do
        let :status, do: 200
        let :raw_body do
          compact_string ~s<
            [
              {"name":"topic_one","publisher":"some-service--uuid","events":123456},
              {"name":"topic_two","publisher":"another-service--uuid","events":42}
            ]
          >
        end

        specify "when requesting an existing topic, it returns the topic payload" do
          topic = %{"events" => 42, "name" => "topic_two", "publisher" => "another-service--uuid"}
          expect Director.get_topic("topic_two") |> to(eq {:ok, topic})
        end

        specify "when requesting an NON-existing topic, it returns nil" do
          expect Director.get_topic("i_do_not_exist") |> to(eq {:ok, nil})
        end
      end

      context "with a NON successful response" do
        let :raw_body, do: ""

        describe "HTTP 400" do
          let :status, do: 400

          it "returns an error with the HTTP status code" do
            expect Director.get_topic("topic_two") |> to(eq {:error, 400})
          end
        end

        describe "HTTP 500" do
          let :status, do: 500

          it "returns an error with the HTTP status code" do
            expect Director.get_topic("topic_two") |> to(eq {:error, 500})
          end
        end
      end
    end
  end


  describe "delete_topic() delete an owned topic" do
    describe "with an invalid topic name" do
      it "raises an exception" do
        expect fn() -> Director.delete_topic("foo bar") end
        |> to(raise_exception Routemaster.Topic.InvalidNameError)
      end
    end

    describe "with a valid topic name" do
      let :topic_name, do: "ducks"
      subject(Director.delete_topic(topic_name()))

      before do
        response_status = status()
        name = topic_name()
        Bypass.expect_once shared.bypass, "DELETE", "/topics/#{name}" , fn conn ->
          Conn.resp(conn, response_status, "")
        end
      end

      context "when deleting an existing owned topic" do
        let :status, do: 204

        it "returns :ok" do
          expect subject() |> to(eq :ok)
        end
      end

      context "when deleting a NON existing topic" do
        let :status, do: 404

        it "returns {:error, 404}" do
          expect subject() |> to(eq {:error, 404})
        end
      end

      context "when deleting an existing but not owned topic" do
        let :status, do: 403

        it "returns {:error, 403}" do
          expect subject() |> to(eq {:error, 403})
        end
      end
    end
  end


  describe "subscribe() subscribes to a list of topics" do
    describe "with an invalid topic name in the list" do
      it "raises an exception" do
        expect fn() -> Director.subscribe(~w(duck Rabbits)) end
        |> to(raise_exception Routemaster.Topic.InvalidNameError)
      end
    end

    describe "with valid topic names" do
      subject(
        Director.subscribe ~w(ducks rabbits), max: 42, timeout: 1_000
      )

      before do
        response_status = status()
        Bypass.expect_once shared.bypass, "POST", "/subscription" , fn conn ->
          {:ok, body, _} = Plug.Conn.read_body(conn)
          {:ok, data} = Poison.decode(body)

          expect data["topics"]   |> to(eq ~w(ducks rabbits))
          expect data["callback"] |> to(eq "http://drain-url.local/events")
          expect data["uuid"]     |> to(eq Config.client_token)
          expect data["max"]      |> to(eq 42)
          expect data["timeout"]  |> to(eq 1_000)

          Conn.resp(conn, response_status, "")
        end
      end


      describe "with a successful response" do
        let :status, do: 204

        it "returns :ok" do
          expect subject() |> to(eq :ok)
        end
      end

      context "with a NON successful response" do
        let :status, do: 400

        it "returns {:error, http_status}" do
          expect subject() |> to(eq {:error, 400})
        end
      end
    end
  end


  describe "unsubscribe() unsubscribes from one topic" do
    describe "with an invalid topic name" do
      it "raises an exception" do
        expect fn() -> Director.unsubscribe("foo bar") end
        |> to(raise_exception Routemaster.Topic.InvalidNameError)
      end
    end

    describe "with a valid topic name" do
      let :topic_name, do: "ducks"
      subject(Director.unsubscribe(topic_name()))

      before do
        response_status = status()
        name = topic_name()
        Bypass.expect_once shared.bypass, "DELETE", "/subscriber/topics/#{name}" , fn conn ->
          Conn.resp(conn, response_status, "")
        end
      end

      context "when deleting from a subscribed topoc" do
        let :status, do: 204

        it "returns :ok" do
          expect subject() |> to(eq :ok)
        end
      end

      context "when deleting a NON existing topic or a topic to which we're not subscribed" do
        let :status, do: 404

        it "returns {:error, 404}" do
          expect subject() |> to(eq {:error, 404})
        end
      end
    end
  end


  describe "unsubscribe_all() unsubscribes from all topics" do
    subject(Director.unsubscribe_all())

    before do
      response_status = status()
      Bypass.expect_once shared.bypass, "DELETE", "/subscriber" , fn conn ->
        Conn.resp(conn, response_status, "")
      end
    end

    context "with a successful response" do
      let :status, do: 204

      it "returns :ok" do
        expect subject() |> to(eq :ok)
      end
    end

    context "with an NON successful response" do
      let :status, do: 400

      it "returns {:error, 400}" do
        expect subject() |> to(eq {:error, 400})
      end
    end
  end


  describe "all_subscribers() GETs a list of subscribers" do
    subject(Director.all_subscribers())

    before do
      response_status = status()
      response_body = raw_body()
      Bypass.expect_once shared.bypass, "GET", "/subscribers", fn conn ->
        conn
        |> Conn.resp(response_status, response_body)
        |> Conn.put_resp_content_type("application/json")
      end
    end

    context "with a successful response" do
      let :status, do: 200
      let :raw_body do
        compact_string ~s<
          [
            {
              "subscriber" : "some-service--uuid",
              "callback" : "https://some.service.test/events",
              "topics" : ["boats", "trains"],
              "events" : { "sent": null, "queued": 0, "oldest": null}
            },
            {
              "subscriber" : "another-service--uuid",
              "callback" : "https://another.service.test/events",
              "topics" : ["trains"],
              "events" : { "sent": null, "queued": 42, "oldest": null}
            }
          ]
        >
      end

      let :parsed_body do
        [
          %{
            "callback" => "https://some.service.test/events",
            "events" => %{"oldest" => nil, "queued" => 0, "sent" => nil},
            "subscriber" => "some-service--uuid",
            "topics" => ["boats", "trains"]
          },
          %{
            "callback" => "https://another.service.test/events",
            "events" => %{"oldest" => nil, "queued" => 42, "sent" => nil},
            "subscriber" => "another-service--uuid",
            "topics" => ["trains"]
          }
        ]
      end

      it "returns a list of maps for a successful response" do
        {:ok, subscribers} = subject()
        expect subscribers |> to(eq parsed_body())
      end
    end

    context "with a NON successful response" do
      let :raw_body, do: ""

      describe "HTTP 400" do
        let :status, do: 400

        it "returns an error with the HTTP status code" do
          expect subject() |> to(eq {:error, 400})
        end
      end

      describe "HTTP 500" do
        let :status, do: 500

        it "returns an error with the HTTP status code" do
          expect subject() |> to(eq {:error, 500})
        end
      end
    end
  end
end
