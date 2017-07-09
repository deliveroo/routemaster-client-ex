defmodule Routemaster.Middleware.BaseUrl do
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
