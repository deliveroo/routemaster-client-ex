defmodule Routemaster.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Routemaster.Redis

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # load config from the ENV
    DeferredConfig.populate(:routemaster)

    children = [
      Redis.worker_spec(:data),
      Redis.worker_spec(:cache),
    ]

    opts = [strategy: :one_for_one, name: Routemaster.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
