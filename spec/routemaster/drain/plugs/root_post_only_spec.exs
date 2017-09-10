defmodule Routemaster.Plugs.RootPostOnlySpec do
  use ESpec, async: true
  use Plug.Test

  alias Routemaster.Plugs.RootPostOnly

  @opts RootPostOnly.init([])

  subject RootPostOnly.call(conn(), @opts)

  let :conn, do: conn(method(), path())

  describe "for valid requests (authenticated POST requests to the root path)" do
    let :method, do: "POST"
    let :path, do: "/"

    it "returns the unchanged conn" do
      expect subject() |> to(eq conn())
    end
  end

  describe "invalid requests" do
    describe "for non POST requests to the root path" do
      let :method, do: "GET"
      let :path, do: "/"


      it "responds with 405" do
        expect subject().status |> to(eq 405)
        expect subject().resp_body |> to(be_empty())
      end
    end


    describe "for any other request (i.e. other verbs AND other paths)" do
      describe "POST /nope" do
        let :method, do: "POST"
        let :path, do: "/nope"


        it "responds with 404" do
          expect subject().status |> to(eq 404)
          expect subject().resp_body |> to(be_empty())
        end
      end

      describe "GET /nope" do
        let :method, do: "GET"
        let :path, do: "/nope"


        it "responds with 404" do
          expect subject().status |> to(eq 404)
          expect subject().resp_body |> to(be_empty())
        end
      end
    end
  end
end
