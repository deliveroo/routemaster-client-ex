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

      # To dynamically spawn async tasks to process the events
      # received by the Drain, _without_ linking the tasks to
      # the caller process that is handling the HTTP request.
      #
      # https://hexdocs.pm/elixir/Task.Supervisor.html#start_link/1
      #
      supervisor(Task.Supervisor,
        [[
          name: DrainEvents.TaskSupervisor,
          restart: :transient,
          # Default values. Tweak to control how failing tasks are handled.
          # max_restarts: 3, max_seconds: 5
        ]],
        [id: :drain_events_task_supervisor]
      ),

      # To run the drains pipelines asyncronously.
      #
      supervisor(Task.Supervisor,
        [[
          name: DrainPipelines.TaskSupervisor,
          restart: :transient,
        ]],
        [id: :drain_pipelines_task_supervisor]
      ),
    ]

    opts = [strategy: :one_for_one, name: Routemaster.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
