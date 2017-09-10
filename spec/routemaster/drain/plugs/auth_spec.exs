defmodule Routemaster.Plugs.AuthSpec do
  use ESpec, async: true
  use Plug.Test

  alias Routemaster.Plugs.Auth
  alias Routemaster.Config

  @opts Auth.init([])

  subject Auth.call(request_conn(), @opts)


  describe "with requests without an authorization header" do
    let :request_conn, do: conn("GET", "/")

    it "responds with 401 and a WWW-Authenticate header" do
      conn = subject()

      expect conn.status |> to(eq 401)
      expect get_resp_header(conn, "www-authenticate") |> to(eq ["Basic"])
    end

    it "halts the Plug chain" do
      conn = subject()

      expect conn.state |> to(eq :sent)
      assert conn.halted
    end
  end


  describe "with requests with an authorization header" do
    describe "when it's NOT Basic auth" do
      let :request_conn do
        conn("GET", "/")
        |> put_req_header("authorization", "Digest blabla")
      end
      
      it "responds with 401 and a WWW-Authenticate header" do
        conn = subject()

        expect conn.status |> to(eq 401)
        expect get_resp_header(conn, "www-authenticate") |> to(eq ["Basic"])
      end

      it "halts the Plug chain" do
        conn = subject()

        expect conn.state |> to(eq :sent)
        assert conn.halted
      end
    end


    describe "when it's Basic auth" do
      let :request_conn do
        conn("GET", "/")
        |> put_req_header("authorization", "Basic #{request_token()}")
      end

      describe "but the data is invalid (e.g. not base64 encoded)" do
        let :request_token, do: "definitely-not-base64-encoded"

        it "responds with 401 and a WWW-Authenticate header" do
          conn = subject()

          expect conn.status |> to(eq 401)
          expect get_resp_header(conn, "www-authenticate") |> to(eq ["Basic"])
        end

        it "halts the Plug chain" do
          conn = subject()

          expect conn.state |> to(eq :sent)
          assert conn.halted
        end
      end


      describe "when the data is valid" do
        describe "but it's not a recognized token" do
          let :request_token, do: Base.encode64("an-unknown-token:x")

          it "responds with 403" do
            conn = subject()
            expect conn.status |> to(eq 403)
          end

          it "halts the Plug chain" do
            conn = subject()

            expect conn.state |> to(eq :sent)
            assert conn.halted
          end
        end


        describe "and it's a recognized token" do
          let :request_token, do: Base.encode64(Config.drain_token <> ":x")

          it "lets the request pass through" do
            conn = subject()

            expect conn.status |> to(be_nil())
            expect conn.state |> to_not(eq :sent)
            refute conn.halted
          end
        end
      end
    end
  end
end
