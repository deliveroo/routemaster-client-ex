defmodule Routemaster.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Routemaster.Redis

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    if Code.ensure_loaded?(DeferredConfig) do
      # When used in a project, if the
      # deferred_config package is included
      # in the parent application, then load
      # the configuration from the unix ENV.
      #
      # deferred_config is an optional dependency,
      # and this block is always executed when
      # working on this library in development.
      DeferredConfig.populate(:routemaster)
    end

    children = [
      Redis.worker_spec(:data),
      Redis.worker_spec(:cache),
    ]

    opts = [strategy: :one_for_one, name: Routemaster.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
