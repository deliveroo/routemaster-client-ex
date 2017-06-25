defmodule Routemaster.Drain.AppSpec do
  use ESpec
  use Plug.Test

  alias Routemaster.Drain.App

  @opts App.init([])


  describe "for valid requests (POST requests to the root path)" do
    let :path, do: "/"
    let :conn, do: post!(path(), payload())

    context "with no events" do
      let :payload, do: "[]"

      it "responds with 204 and no body" do
        expect conn().status |> to(eq 204)
        expect conn().resp_body |> to(be_empty())
      end
    end


    # context "more examples here" do
    #   it "pending" do
    #   end  
    # end
  end


  describe "invalid requests" do
    describe "for POST requests to another path" do
      let :path, do: "/foo"
      let :payload, do: "[]"

      let :conn, do: post!(path(), payload())

      it "responds with 404" do
        expect conn().status |> to(eq 404)
        expect conn().resp_body |> to(be_empty())
      end
    end


    describe "for non-POST requests" do
      let :path, do: "/"
      let :payload, do: "[]"

      let :conn do
        conn("GET", path(), payload())
        |> put_req_header("content-type", "application/json")
        |> App.call(@opts)
      end

      it "responds with 405" do
        expect conn().status |> to(eq 405)
        expect conn().resp_body |> to(be_empty())
      end
    end


    describe "for non-JSON POST requests" do
      let :path, do: "/"
      let :payload, do: "foo=bar"

      let :conn do
        the_conn = 
          conn("POST", path(), payload())
          |> put_req_header("content-type", "application/x-www-form-urlencoded")

        try do
          App.call(the_conn, @opts)
        rescue Plug.Parsers.UnsupportedMediaTypeError -> nil
        end

        the_conn
      end

      it "responds with 415" do
        {status, _headers, body} = sent_resp(conn())

        expect status |> to(eq 415)
        expect body |> to(be_empty())
      end
    end
  end


  # For JSON bodies, the request body (the params) must be a binary
  # and the content-type must be set. Using a Map instead will
  # automatically set the content-type to multipart.
  #
  def post!(path, body) when is_binary(body) do
    conn("POST", path, body)
    |> put_req_header("content-type", "application/json")
    |> App.call(@opts)
  end
end
