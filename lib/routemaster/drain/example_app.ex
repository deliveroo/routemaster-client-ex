defmodule Routemaster.Drain.ExampleApp do
  @moduledoc """
  A Plug to receive events over HTTP.

  This is just an example of how to build a Drain app, and was
  built using the `Routemaster.Drain` module.

  Please check the sourcecode for the details.
  """

  use Routemaster.Drain

  drain Routemaster.Drains.Siphon,
    topic: "rabbits", to: Routemaster.ExampleRabbitSiphon

  drain Routemaster.Drains.Dedup
  drain Routemaster.Drains.IgnoreStale
  drain Routemaster.Drains.FetchAndCache
end


defmodule Routemaster.ExampleRabbitSiphon do
  @moduledoc false

  require Logger

  def call(events) do
    Logger.info """
    [#{__MODULE__}]: #{length(events)} events siphoned:
    #{inspect events}
    """
  end
end
