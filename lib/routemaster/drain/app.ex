defmodule Routemaster.Drain.App do
  @moduledoc """
  A Plug to receive events over HTTP.

  This is just an example of how to build a Drain app, and was
  built using the `Routemaster.Drain` module.

  Please check the sourcecode for the details.
  """

  use Routemaster.Drain
  

  drain Drain.Plugs.Dedup
  # drain Drain.Plugs.IgnoreStale
  drain Drain.Plugs.FetchAndCache
end
