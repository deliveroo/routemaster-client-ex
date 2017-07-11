defmodule Routemaster.DirectorSpec do
  use ESpec
  import Routemaster.TestUtils

  alias Routemaster.Director
  alias Plug.Conn

  before do
    bypass = Bypass.open(port: 4567)
    {:shared, bypass: bypass}
  end

  finally do
    Bypass.verify_expectations!(shared.bypass)
  end

  describe "topics() GETs a list of topics" do
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
        %Tesla.Env{status: 200, body: body} = Director.topics()
        expect body |> to(eq parsed_body())
      end  
    end
    
  end
end
