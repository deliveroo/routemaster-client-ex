defmodule Routemaster.Middleware.BaseUrl do
  @moduledoc """
  Dynamic base URL middleware.

  Used in place of [Tesla's builtin BaseUrl](https://hexdocs.pm/tesla/Tesla.Middleware.BaseUrl.html)
  middleware because that freezes the URL at compile time and
  requires a [clunky workaround](https://github.com/teamon/tesla/tree/v0.7.1#dynamic-middleware)
  to read it dynamically.

  A dynamic [`BaseUrlFromConfig`](https://github.com/teamon/tesla/blob/v0.7.1/lib/tesla/middleware/core.ex#L121)
  middleware is provided by Tesla (undocumented), but it's quite rigid
  on where to find the configured URL, and since we control the requirements
  for this library it's easier to just use this custom middleware, that is
  more specific to our use case.


  Also, at the moment we're making some strong assumptions on the format
  of the configured URL (no trailing slash), so that the implementation
  of this middleware can be simpler and faster. This will break if people
  configure URLs with a trailing slash.


  This middleware does not require any option and automatically
  reads the base URL from the application configuration.

  Example:

      defmodule MyClient do
        use Tesla
        plug Routemaster.Middleware.BaseUrl
      end
  """

  alias Routemaster.Config

  def call(env, next, _opts) do
    env
    |> apply_base()
    |> Tesla.run(next)
  end

  defp apply_base(env) do
    %{env | url: Config.bus_url <> env.url}
  end
end
