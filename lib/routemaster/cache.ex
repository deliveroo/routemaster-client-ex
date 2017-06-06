defmodule Routemaster.Cache do
  @moduledoc """
  A persistent cache that survives application restarts,
  backed by Redis.
  """

  # todo: make this configurable or dynamic
  @ttl 3600 # seconds
  @prefix "cache:"
  @redis Routemaster.Redis.cache()

  @doc """
  Reads a key-value and returns an Elixr term, in a tuple.

      iex> Routemaster.Cache.read(:apple)
      {:miss, nil}
      iex> Routemaster.Cache.write(:apple, %{is: "a", good: "fruit"})
      {:ok, %{is: "a", good: "fruit"}}
      iex> Routemaster.Cache.read(:apple)
      {:ok, %{is: "a", good: "fruit"}}
  """
  def read(key) do
    case @redis.get(ns(key)) do
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
  def write(key, term) do
    case @redis.setex(ns(key), @ttl, serialize(term)) do
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
  def clear(key) do
    case @redis.del(ns(key)) do
      {:ok, _n} -> :ok # n is 0 or 1
      _ -> :error
    end
  end


  defp ns(key) do
    @prefix <> to_string(key)
  end

  defp serialize(term),   do: :erlang.term_to_binary(term)
  defp deserialize(data), do: :erlang.binary_to_term(data)
end
