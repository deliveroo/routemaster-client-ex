defmodule Routemaster.Fetcher do
  @moduledoc """
  API client to fetch resources linked to from the events.
  """

  use Tesla, docs: false

  alias Routemaster.Config

  adapter Tesla.Adapter.Hackney, Config.fetcher_http_options
end
