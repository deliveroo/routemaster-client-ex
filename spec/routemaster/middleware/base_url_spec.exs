defmodule Routemaster.Middleware.BaseUrlSpec do
  use ESpec

  describe "Tesla.Middleware.BaseUrl" do
    alias Routemaster.Middleware.BaseUrl

    it "joins a path with the configured base URL" do
      env = BaseUrl.call(%Tesla.Env{url: "/path"}, [], nil)
      expect env.url |> to(eql "https://example.com/path")
    end
  end
end
