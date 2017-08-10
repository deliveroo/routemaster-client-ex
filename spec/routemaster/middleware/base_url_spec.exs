defmodule Routemaster.Middleware.BaseUrlSpec do
  use ESpec, async: true

  alias Routemaster.Config

  describe "Tesla.Middleware.BaseUrl" do
    alias Routemaster.Middleware.BaseUrl

    it "joins a path with the configured base URL" do
      env = BaseUrl.call(%Tesla.Env{url: "/path"}, [], nil)
      expect env.url |> to(eql "#{Config.bus_url}/path")
    end
  end
end
