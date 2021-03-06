defmodule Routemaster.Cache do
  @moduledoc """
  A persistent cache that survives application restarts,
  backed by Redis.
  """

  alias Routemaster.Config
  import Routemaster.Redis, only: [serialize: 1, deserialize: 1]

  @type fallback :: (() -> any)

  @redis Routemaster.Redis.Cache

  @doc """
  Reads a key-value and returns an Elixr term, in a tuple.

      iex> Routemaster.Cache.read(:apple)
      {:miss, nil}
      iex> Routemaster.Cache.write(:apple, %{is: "a", good: "fruit"})
      {:ok, %{is: "a", good: "fruit"}}
      iex> Routemaster.Cache.read(:apple)
      {:ok, %{is: "a", good: "fruit"}}
  """
  @spec read(atom | binary) :: {:ok, any} | {:miss, nil} | {:error, any}
  def read(key) do
    case @redis.get(key) do
      {:ok, nil} ->
        {:miss, nil}
      {:ok, data} ->
        {:ok, deserialize(data)}
      {:error, _} = error ->
        error
    end
  end

  @doc """
  Writes a key-value and returns the written value, in a tuple.

      iex> Routemaster.Cache.write(:pear, [1, 2, 3])
      {:ok, [1, 2, 3]}
      iex> Routemaster.Cache.read(:pear)
      {:ok, [1, 2, 3]}
  """
  @spec write(atom | binary, any) :: {:ok, any} | {:error, any}
  def write(key, term) do
    case @redis.setex(key, Config.cache_ttl, serialize(term)) do
      {:ok, "OK"} ->
        {:ok, term}
      {:error, _} = error ->
        error
    end
  end

  @doc """
  Tries to read `key` from the cache, and returns the stored value
  if anything is found. If no vlaue is found in the cache, it
  executes the `fallback` function, caches the result, and returns
  the value in a tuple.

      iex> Routemaster.Cache.read(:peach)
      {:miss, nil}
      iex> Routemaster.Cache.fetch(:peach, fn() -> "apricot" end)
      {:ok, "apricot"}
      iex> Routemaster.Cache.fetch(:peach, fn() -> "coconut" end)
      {:ok, "apricot"}
      iex> Routemaster.Cache.read(:peach)
      {:ok, "apricot"}
  """
  @spec fetch(atom | binary, fallback) :: {:ok, any} | {:error, any}
  def fetch(key, fallback) do
    case read(key) do
      {:miss, _} ->
        write(key, fallback.())
      {:ok, _} = value ->
        value
      {:error, _} = error ->
        error
    end
  end

  @doc """
  It clears a key-value from the cache

      iex> Routemaster.Cache.write(:mango, "so good")
      {:ok, "so good"}
      iex> Routemaster.Cache.clear(:mango)
      :ok
      iex> Routemaster.Cache.read(:mango)
      {:miss, nil}

  """
  @spec clear(atom | binary) :: :ok | :error
  def clear(key) do
    case @redis.del(key) do
      {:ok, _n} -> :ok # n is 0 or 1
      _ -> :error
    end
  end
end
