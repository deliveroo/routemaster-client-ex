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

  def drain_token do
    Application.get_env(@app, :drain_token)
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

  def fetcher_http_options do
    Application.get_env(@app, :fetcher_http_options, @hackney_defaults)
  end

  @doc """
  Returns the authentication credentials for other services with which
  we might want to interact. The credentials need to be configured
  beforehand.
  """
  def service_auth_credentials do
    case Application.get_env(@app, :service_auth_credentials_cached) do
      nil ->
        data = load_service_auth_credentials()
        Application.put_env(@app, :service_auth_credentials_cached, data, persistent: true)
        data
      current_value ->
        current_value
    end
  end


  # Load the raw configuration value, which is a comma-separated
  # string of auth tokens in the form: "hostname:username:authtoken".
  # The values are properly split and stored in a lookup Map.
  #
  defp load_service_auth_credentials do
    Application.get_env(@app, :service_auth_credentials)
    |> String.split(",")
    |> Enum.map(fn(str) ->
      [host, user, token] = String.split(str, ":")
      {host, [user: user, token: token]}
    end)
    |> Enum.into(%{})
  end


  @doc """
  Returns the username and token for a given hostname. The hostname
  must be found in the credentials returned by `service_auth_credentials/0`
  """
  def service_auth_for(host) do
    case service_auth_credentials()[host] do
      nil -> :error
      data -> {:ok, data} 
    end
  end
end
