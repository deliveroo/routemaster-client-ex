defmodule Routemaster.Drains.FetchAndCache do
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

  @supervisor DrainEvents.TaskSupervisor

  def init(opts), do: opts

  def call(conn, _opts) do
    Enum.each(conn.assigns.events, &async_fetch(&1))
    conn
  end


  defp async_fetch(event) do
    Task.Supervisor.start_child(@supervisor, fn() ->
      Logger.debug fn ->
        Utils.debug_message("Drain.FetchAndCache", "fetching #{event.url}", :yellow)
      end
      cache_bust(event)
      fetch(event.url)
    end)
  end


  # Don't bust the cache if the event is a noop
  #
  defp cache_bust(%{type: "noop"}), do: nil
  defp cache_bust(%{url: url}),     do: Cache.clear(url)


  # If there is no data yet, or if the cache has just been busted,
  # then this will automatically fetch and cache the data.
  #
  # If the event is a noop (and the caceh has not been busted), then
  # we still want this to check the cache first, so that we can do
  # nothing if the cached value is present or fetch the resource if
  # the cache was already empty (e.g. if we're backfilling a new cache).
  #
  defp fetch(url) do
    Fetcher.get(url)
  end
end
