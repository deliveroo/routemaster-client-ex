defmodule Routemaster.Drain.EventState do
  @moduledoc """
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
  """
  @spec save(Event.t) :: :ok | {:error, any}
  def save(%Event{url: url, t: t}) do
    state = %__MODULE__{url: url, t: t}

    case _redis_set(url, state) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end


  @doc """
  """
  @spec stale?(Event.t) :: boolean
  def stale?(%Event{url: url, t: t}) do
    latest_recorded = get(url)
    latest_recorded.t >= t
  end



  defp _redis_get(url) do
    @redis.get ns(url)
  end

  defp _redis_set(key, value) do
    @redis.setex ns(key), Config.cache_ttl, serialize(value)
  end


  defp ns(base) do
    @key_prefix <> to_string(base)
  end
end
