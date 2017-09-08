defmodule Routemaster.Drain.Plugs.IgnoreStaleSpec do
  use ESpec, async: true
  use Plug.Test

  alias Routemaster.Drain.Plugs.IgnoreStale
  alias Routemaster.Drain.Event
end
