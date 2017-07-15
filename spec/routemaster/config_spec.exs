defmodule Routemaster.ConfigSpec do
  use ESpec
  alias Routemaster.Config

  describe "user_agent()" do
    it "returns a string" do
      expect Config.user_agent |> to(start_with "routemaster-client-ex-v")
    end
  end

  describe "redis_config(cache)" do
    subject(Config.redis_config(:cache))

    before do
      # capture the initial configuration
      initial_config = Application.get_env(:routemaster, :redis_cache)
      {:shared, initial_config: initial_config}
    end

    finally do
      # restore the initial configuration
      Mix.Config.persist(routemaster: [redis_cache: shared.initial_config])
    end


    context "normally" do
      it "returns a keyword list" do
        expect(subject()) |> to(be_list())
        first = hd subject()
        expect(first) |> to(be_tuple())
      end

      it "contains some connection settings" do
        expect(subject()[:host]) |> to(eq "localhost")
        expect(subject()[:port]) |> to(eq 6379)
        expect(subject()[:database]) |> to(eq 5)
      end
    end

    context "when configured with a string" do
      before do
        uri = "redis://42.42.42.42:1337/1"
        Mix.Config.persist(routemaster: [redis_cache: uri])
        {:shared, uri: uri}
      end

      it "returns the string" do
        expect(subject()) |> to(eq shared.uri)
      end
    end
  end


  describe "bus_url" do
    it "returns a string" do
      expect Config.bus_url |> to(eql "http://localhost:4567")
    end
  end

  describe "api_token" do
    it "returns a string" do
      expect Config.api_token |> to(eql "a-test-api-token")
    end
  end

  describe "client_token" do
    it "returns a string" do
      expect Config.client_token |> to(eql "a-test-client-token")
    end
  end

  describe "drain_url" do
    it "returns a string" do
      expect Config.drain_url |> to(eql "http://drain-url.local/events")
    end
  end
end
