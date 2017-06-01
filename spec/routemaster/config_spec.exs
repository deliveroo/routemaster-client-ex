defmodule Routemaster.ConfigSpec do
  use ESpec
  alias Routemaster.Config

  describe "redis_config" do
    subject(Config.redis_config())

    before do
      # capture the initial configuration
      initial_config = Application.get_env(:routemaster, :redis)
      {:shared, initial_config: initial_config}
    end

    finally do
      # restore the initial configuration
      Mix.Config.persist(routemaster: [redis: shared.initial_config])
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
        Mix.Config.persist(routemaster: [redis: uri])
        {:shared, uri: uri}
      end

      it "returns the string" do
        expect(subject()) |> to(eq shared.uri)
      end
    end
  end
end
