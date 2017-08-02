defmodule Routemaster.Fetcher.Middleware.Caching do
  @moduledoc false

  alias Routemaster.Cache
  require Logger


  def call(env, next, _options) do
    if env.opts[:cache] do
      lookup_or_fetch(env, next)
    else
      http_request(env, next)
    end
  end


  # Very simple caching
  #
  defp lookup_or_fetch(env, next) do
    key = cache_key(env)

    case Cache.read(key) do
      {:ok, data} ->
        data
      {:miss, _} ->
        http_request_and_cache(env, next, key)
    end
  end


  defp http_request_and_cache(env, next, key) do
    response = http_request(env, next)
    cache_successful_response(key, response)
    response
  end


  defp http_request(env, next) do
    Tesla.run(env, next)
  end


  defp cache_key(env) do
    env.url
  end


  defp cache_successful_response(key, %{status: s} = response) when s in 200..299 do
    cache_response(key, response)
  end
  defp cache_successful_response(_, _), do: nil


  defp cache_response(key, data) do
    case Cache.write(key, data) do
      {:ok, _} ->
        nil
      {:error, _} = error ->
        Logger.error "Routemaster.Fetcher: can't write HTTP response to cache. Error: #{inspect error}, data: #{inspect data}"
        nil
    end
  end
end
