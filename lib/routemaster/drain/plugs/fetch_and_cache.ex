defmodule Routemaster.Drain.Plugs.FetchAndCache do
  @moduledoc """
  This plug iterates through the list of event payloads
  in `conn` and, for each one, starts a supervised `Task`
  to fetch the data asynchronously.

  Ideally, this should be an entry point to add adapters
  for different async backends, for example independent
  background job processors (e.g. exq, verk or toniq).
  """

  require Logger
  alias Routemaster.Utils
  alias Routemaster.Fetcher
  alias Routemaster.Cache

  @supervisor DrainEventHandler.TaskSupervisor

  def init(opts), do: opts

  def call(conn, _opts) do
    Enum.each(conn.assigns.events, &async_fetch(&1.url))
    conn
  end


  defp async_fetch(url) do
    Task.Supervisor.start_child(@supervisor, fn() ->
      Logger.debug fn ->
        Utils.debug_message("Drain.FetchAndCache", "fetching #{url}", :yellow)
      end
      Cache.clear(url)
      Fetcher.get(url) # this will automatically re-cache it
    end)
  end
end
