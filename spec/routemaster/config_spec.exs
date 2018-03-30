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
      initial_config = Application.get_env(:routemaster_client, :redis_cache)
      {:shared, initial_config: initial_config}
    end

    finally do
      # restore the initial configuration
      Mix.Config.persist(routemaster_client: [redis_cache: shared.initial_config])
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
        Mix.Config.persist(routemaster_client: [redis_cache: uri])
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

  describe "bus_api_token" do
    it "returns a string" do
      expect Config.bus_api_token |> to(eql "a-test-api-token")
    end
  end

  describe "bus_api_auth_header" do
    it "returns a basic auth header value" do
      expect Config.bus_api_auth_header |> to(eql "Basic YS10ZXN0LWFwaS10b2tlbjp4")
    end
  end

  describe "drain_token" do
    it "returns a string" do
      expect Config.drain_token |> to(eql "a-test-drain-token")
    end
  end

  describe "drain_url" do
    it "returns a string" do
      expect Config.drain_url |> to(eql "http://drain-url.local/events")
    end
  end

  specify "director_http_options() returns some options for hackney" do
    [{:recv_timeout, rec_t}, {:connect_timeout, con_t}] = Config.director_http_options
    expect rec_t |> to(be_integer())
    expect con_t |> to(be_integer())
  end

  specify "publisher_http_options() returns some options for hackney" do
    [{:recv_timeout, rec_t}, {:connect_timeout, con_t}] = Config.publisher_http_options
    expect rec_t |> to(be_integer())
    expect con_t |> to(be_integer())
  end

  specify "fetcher_http_options() returns some options for hackney" do
    [{:recv_timeout, rec_t}, {:connect_timeout, con_t}] = Config.fetcher_http_options
    expect rec_t |> to(be_integer())
    expect con_t |> to(be_integer())
  end


  describe "service_auth_credentials" do
    subject(Config.service_auth_credentials())

    it "returns a Map" do
      expect subject() |> to(be_map())
    end

    describe "in the Map" do
      specify "keys are strings" do
        keys = Map.keys(subject())

        Enum.each keys, fn(key) ->
          expect key |> to(be_binary())
        end
      end


      specify "and values are strings starting with Basic" do
        values = Map.values(subject())

        Enum.each values, fn(value) ->
          expect value |> to(be_binary())
          expect value |> to(start_with "Basic ")
        end
      end
    end

    it "can be used to check auth credentials for services" do
      expect subject() |> to(
        eq %{
          "localhost" => "Basic YS11c2VyOmEtdG9rZW4=",
          "foobar.local" => "Basic bmFtZTpzZWNyZXQ="
        }
      )
    end
  end


  describe "service_auth_for(hostname)" do
    it "returns {:ok, [stored auth credentials]} for a known hostname" do
      expect Config.service_auth_for("localhost")
      |> to(eq {:ok, "Basic YS11c2VyOmEtdG9rZW4="})

      expect Config.service_auth_for("foobar.local")
      |> to(eq {:ok, "Basic bmFtZTpzZWNyZXQ="})
    end

    it "returns :error for unknown hostnames" do
      expect Config.service_auth_for("unknown.host.com") |> to(eq :error)
    end
  end


  describe "cache_ttl" do
    it "returns an integer number of seconds" do
      expect Config.cache_ttl |> to(eq "86400")
    end
  end
end
