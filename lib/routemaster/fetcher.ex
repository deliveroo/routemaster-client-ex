defmodule Routemaster.Fetcher do
  use Tesla, docs: false
  adapter Tesla.Adapter.Hackney
end
