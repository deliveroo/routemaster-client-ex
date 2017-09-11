defmodule Routemaster.Drain.EventState do
  @moduledoc """
  Persisted data.

  Each `EventState` is associated to the URL of a resource and
  stores the timestamp of the latest Drain event received for
  that URL.

  They are stored in Redis, with the URL acting as key.

  They are used to keep track of the most recent event for a
  resource and to filter out stale events receivied out of order.
  """

  alias Routemaster.Drain.Event
  alias Routemaster.Config

  import Routemaster.Redis, only: [serialize: 1, deserialize: 1]

  @redis Routemaster.Redis.Data
  @key_prefix "drain:event-state:"

  defstruct [:url, :t]

  @type t :: %{
    :__struct__ => __MODULE__,
    required(:url) => Event.url,
    required(:t) => Event.timestamp,
  }


  @doc """
  Checks if a `Routemaster.Drain.Event` is more recent than the
  previous received events for the same URL (for the same resource).

  In practical terms, it compares the timestamp `r` of the event with
  the stored timestamp of the most recent previously received event.
  """
  @spec fresh?(Event.t) :: boolean
  def fresh?(%Event{url: url, t: t}) do
    latest_recorded = get(url)
    latest_recorded.t < t
  end


  @doc """
  Looks up and `EventState` struct in Redis by URL. If nothing is
  found, it returns a null struct with timestamp equal to zero
  which will be considered older than any real data.
  """
  @spec get(Event.url) :: t
  def get(url) do
    case _redis_get(url) do
      {:ok, data} when not is_nil(data) ->
        deserialize(data)
      _ ->
        %__MODULE__{url: url, t: 0}
    end
  end


  @doc """
  Given a `Routemaster.Drain.Event`, it stores an `EventState` in
  Redis with the event URL and timestamp.
  """
  @spec save(Event.t) :: :ok | {:error, any}
  def save(%Event{url: url, t: t}) do
    state = %__MODULE__{url: url, t: t}

    case _redis_set(url, serialize(state)) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end


  defp _redis_get(key) do
    @redis.get ns(key)
  end

  defp _redis_set(key, value) do
    @redis.setex ns(key), Config.cache_ttl, value
  end


  defp ns(base) do
    @key_prefix <> to_string(base)
  end
end
