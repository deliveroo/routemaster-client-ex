defmodule Routemaster.Drain.App do
  @moduledoc """
  A Plug to receive events over HTTP.
  """

  use Routemaster.Drain
  

  plug Drain.Plugs.Dedup
  # plug Drain.Plugs.IgnoreStale

  plug Drain.Plugs.FetchAndCache

  plug Drain.Plugs.Terminator

end
