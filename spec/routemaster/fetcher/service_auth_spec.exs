defmodule Routemaster.Fetcher.ServiceAuthSpec do
  use ESpec

  import Routemaster.TestUtils
  alias Routemaster.Fetcher.ServiceAuth


  describe "it authenticates requests" do
    let :env, do: %Tesla.Env{url: url()}

    # Passing an empty list for the Testla stack will ensure
    # that "Tesla.run(env, next)" is a noop.
    #
    subject ServiceAuth.call(env(), [], nil)

    context "with a known host" do
      let :url, do: "https://localhost/hamsters/1"

      it "sets the Authentication HTTP header in the env" do
        %Tesla.Env{headers: headers} = env()
        expect headers |> to(be_map())
        expect headers |> to(be_empty())
        expect headers["Authorization"] |> to(be_nil())

        %Tesla.Env{headers: headers} = subject()
        expect headers |> to(be_map())
        expect headers |> to_not(be_empty())
        expect headers["Authorization"] |> to(eq localhost_basic_auth())
      end
    end

    context "with an unknown host" do
      let :url, do: "https://unknown.com/rabbits/1"

      it "raises an exception" do
        error_type = Routemaster.Fetcher.ServiceAuth.MissingCredentialsError

        expect fn()-> subject() end
        |> to(raise_exception error_type, "Can't find auth credentials for host: unknown.com")
      end
    end
  end
end
