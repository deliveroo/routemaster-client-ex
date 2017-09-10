defmodule Routemaster.Drain.App do
  @moduledoc """
  A Plug to receive events over HTTP.
  """

  use Routemaster.Drain
  

  drain Drain.Plugs.Dedup
  # drain Drain.Plugs.IgnoreStale

  drain Drain.Plugs.FetchAndCache


end
