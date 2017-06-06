defmodule Routemaster.Cache do

  # todo: make this configurable or dynamic
  @ttl 3600 # seconds
  @prefix "cache:"
  @redis Routemaster.Redis.cache()

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


  def write(key, term) do
    case @redis.setex(ns(key), @ttl, serialize(term)) do
      {:ok, "OK"} ->
        {:ok, term}
      {:error, _} = error ->
        error
    end
  end


  def fetch(key, fun) do
    case read(key) do
      {:miss, _} ->
        write(key, fun.())
      {:ok, _} = value ->
        value
      {:error, _} = error ->
        error
    end
  end


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
