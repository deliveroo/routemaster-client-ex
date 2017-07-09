defmodule Routemaster.Config do
  @moduledoc false
  @app :routemaster

  @default_redis_config [
    host: "localhost",
    port: 6379,
    database: 0,
  ]

  @doc """
  Returns the connection condfiguration for Redis.
  It could be either a Keyword List of parameters or a
  binary URI.
  """
  def redis_config(type)

  def redis_config(:cache) do
    read_redis_config(:redis_cache)
  end

  def redis_config(:data) do
    read_redis_config(:redis_data)
  end


  defp read_redis_config(key) do
    case Application.get_env(@app, key, []) do
      uri  when is_binary(uri) ->
        uri
      opts when is_list(opts) ->
        Keyword.merge(@default_redis_config, opts)
    end
  end


  def bus_url do
    Application.get_env(@app, :bus_url)
  end

  def api_token do
    Application.get_env(@app, :api_token)
  end

  def client_token do
    Application.get_env(@app, :client_token)
  end
end
