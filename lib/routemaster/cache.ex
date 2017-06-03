defmodule Routemaster.Cache do
  alias Routemaster.Redis

  @ttl 60 # seconds
  @prefix "cache:"

  def read(key) do
    case Redis.get(ns(key)) do
      {:ok, nil} ->
        {:miss, nil}
      {:ok, data} ->
        {:ok, deserialize(data)}
      {:error, _} = error ->
        error
    end
  end


  def write(key, term) do
    case Redis.setex(ns(key), @ttl, serialize(term)) do
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
    Redis.del(ns(key))
  end


  defp ns(key) do
    @prefix <> to_string(key)
  end

  defp serialize(term),   do: :erlang.term_to_binary(term)
  defp deserialize(data), do: :erlang.binary_to_term(data)
end
