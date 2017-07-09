defmodule Routemaster.Middleware.BasicAuthSpec do
  use ESpec

  describe "Tesla.Middleware.BasicAuth" do
    alias Routemaster.Middleware.BasicAuth

    it "joins sets the Authorization request header using the configured api token" do
      initial_headers = %{"Accept" => "application/json"}
      env = BasicAuth.call(%Tesla.Env{headers: initial_headers}, [], nil)

      auth_header = "Basic #{Base.encode64("a-test-api-token:x")}"
      expected_headers = %{"Accept" => "application/json", "Authorization" => auth_header}

      expect env.headers |> to(eq expected_headers)
    end
  end
end
