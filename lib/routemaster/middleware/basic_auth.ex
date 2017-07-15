defmodule Routemaster.Middleware.BasicAuth do
  @moduledoc """
  Dynamic Basic authentication middleware.

  Used in place of [Tesla's builtin BasicAuth](https://hexdocs.pm/tesla/Tesla.Middleware.BasicAuth.html)
  middleware because that freezes the token at compile time and
  requires a [clunky workaround](https://github.com/teamon/tesla/tree/v0.7.1#dynamic-middleware)
  to read it dynamically.

  This middleware does not require any option and automatically
  reads the token from the application configuration.

  Example:

      defmodule MyClient do
        use Tesla
        plug Routemaster.Middleware.BasicAuth
      end
  """

  alias Routemaster.Config

  def call(env, next, _opts) do
    env
    |> Map.update!(:headers, &Map.merge(&1, auth_header()))
    |> Tesla.run(next)
  end

  defp auth_header do
    token = Base.encode64(Config.api_token <> ":x")
    %{"Authorization" => "Basic #{token}"}
  end
end

