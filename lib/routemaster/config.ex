defmodule Routemaster.Config do
  @moduledoc """
  Centralized access to the client configuration.
  """

  @app :routemaster

  @default_redis_config [
    host: "localhost",
    port: 6379,
    database: 0,
  ]

  @user_agent "routemaster-client-ex-v#{Routemaster.Mixfile.version()}"

  @doc """
  The user-agent HTTP header used when talking with the bus server
  and when fetching entities from their URLs.
  """
  def user_agent, do: @user_agent


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

  def drain_url do
    Application.get_env(@app, :drain_url)
  end


  @hackney_defaults [{:recv_timeout, 5_000}, {:connect_timeout, 8_000}]

  @doc """
  Options passed to the `Director`'s `hackney` adapter.  
  See [the hackney docs](https://github.com/benoitc/hackney/blob/master/doc/hackney.md)
  for more details.
  """
  def director_http_options do
    Application.get_env(@app, :director_http_options, @hackney_defaults)
  end

  def publisher_http_options do
    Application.get_env(@app, :publisher_http_options, @hackney_defaults)
  end
end
