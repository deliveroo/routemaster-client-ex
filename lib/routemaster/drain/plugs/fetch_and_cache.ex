defmodule Routemaster.Drain.Plugs.FetchAndCache do
  @moduledoc """
  This plug will iterate through the list of event payloads
  in `conn` and, for each one, start a supervised `Task` to
  fetch the data asynchronously.
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
