defmodule Routemaster.Fetcher.Caching do
  @moduledoc """
  Response caching middleware.

  For each HTTP request (the `Fetcher` only supports GET requests)
  it looks up a response in the cache using the URL as key.

  If a cached response is found, it is immediately returned. If
  nothing is found, it executes the HTTP request and then it
  caches successful (200..299) responses before returning them
  to the caller. Unsuccessful responses and redirects (e.g. 302,
  404 or 500) are never cached and always returned to the caller.

  If writing to the cache fails for some reason, an error is logged
  but the request chain is not halted and the response is normally
  returned.

  The entire cache layer (lookups and writes) can be bypassed by
  passing the `cache: false` option to `Routemaster.Fetcher.get/2`.

  ## Caveats

  At the moment the caching strategy is very simple and does not
  implement the features of the official Ruby client. For example,
  it doesn't separately cache different representations of the same
  entities (i.e. API version and language headers) and as a consequence
  the `Fetcher` doesn't _yet_ support that kind of granularity.

  Also, the entire `Tesla.Env` structure is compressed and cached as
  a Redis string, while it might be more efficient (space wise) to
  use a Redis Hash for different fields and rebuild the struct later.

  Compressing the data in Elixir is also something to be benchmarked,
  since it really boils down to CPU time vs Network IO time wile
  exchanging payloads with the cache.
  """

  alias Routemaster.Cache
  require Logger


  def call(env, next, _options) do
    cache_enabled = env.opts[:cache]
    env = %{env | opts: Keyword.delete(env.opts, :cache)}

    if cache_enabled do
      lookup_or_fetch(env, next)
    else
      http_request(env, next)
    end
  end


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
