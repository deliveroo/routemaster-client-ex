defmodule Routemaster.Config do
  @moduledoc """
  Centralized access to the client configuration.
  """
  require Logger
  alias Routemaster.Utils

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
  @spec user_agent :: binary
  def user_agent, do: @user_agent


  @doc """
  Returns the connection condfiguration for Redis.
  It could be either a Keyword List of parameters or a
  binary URI.
  """
  @spec redis_config(atom) :: binary | Keyword.t
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


  @doc """
  The HTTPS URL of the Routemaster event bus server.
  """
  @spec bus_url :: binary
  def bus_url do
    Application.get_env(@app, :bus_url)
  end


  @doc """
  The API token to authenticate requests to the event bus server.
  """
  @spec api_token :: binary
  def api_token do
    Application.get_env(@app, :api_token)
  end


  @doc """
  The HTTP Basic Authorization Header value to authenticate
  requests to the event bus server. It's derived from
  a base64-encoded `Config.api_token`.
  """
  @spec api_auth_header :: binary
  def api_auth_header do
    case Application.fetch_env(@app, :api_auth_header) do
      {:ok, value} ->
        value
      :error ->
        Logger.debug "Routemaster: loading bus server auth credentials"
        data = Utils.build_auth_header(api_token(), "x")
        Application.put_env(@app, :api_auth_header, data, persistent: true)
        data
    end
  end


  @doc """
  The auth token used by the Drain to authenticate incoming HTTP requests. This
  token is specific to this application (an event consumer, AKA subscriber).

  This token is sent to the event bus server when subscribing to topics, where
  it will be stored with this subscriber's metadata. Later, when delivering
  events, the server will send it back in the HTTP Authorization header of the
  POST requests to this drain.
  """
  @spec drain_token :: binary
  def drain_token do
    Application.get_env(@app, :drain_token)
  end


  @doc """
  The HTTPS URL where this application will mount the Drain app. This is usually
  a path, and that is where the event bus server will send HTTP POST requests to
  deliver events.

  This URL is sent to the event bus server when subscribing to topics.
  """
  @spec drain_url :: binary
  def drain_url do
    Application.get_env(@app, :drain_url)
  end


  @hackney_defaults [{:recv_timeout, 5_000}, {:connect_timeout, 8_000}]

  @doc """
  Options passed to the `Director`'s `hackney` adapter.  
  See [the hackney docs](https://github.com/benoitc/hackney/blob/master/doc/hackney.md)
  for more details.
  """
  @spec director_http_options :: Keyword.t
  def director_http_options do
    Application.get_env(@app, :director_http_options, @hackney_defaults)
  end

  @doc """
  Options passed to the `Publisher`'s `hackney` adapter.  
  See [the hackney docs](https://github.com/benoitc/hackney/blob/master/doc/hackney.md)
  for more details.
  """
  @spec publisher_http_options :: Keyword.t
  def publisher_http_options do
    Application.get_env(@app, :publisher_http_options, @hackney_defaults)
  end

  @doc """
  Options passed to the `Fetcher`'s `hackney` adapter.  
  See [the hackney docs](https://github.com/benoitc/hackney/blob/master/doc/hackney.md)
  for more details.
  """
  @spec fetcher_http_options :: Keyword.t
  def fetcher_http_options do
    Application.get_env(@app, :fetcher_http_options, @hackney_defaults)
  end

  @doc """
  Authentication credentials for other services with which we're going to
  interact. These are usually the origins or sources of the entities linked
  to in the events.

  It returns a Map where the keys are the hostnames of the other services
  (binaries) and the values are the pre-built values for the HTTP Authorization
  header.

  The credentials need to be configured beforehand.
  """
  @spec service_auth_credentials :: %{optional(binary) => binary}
  def service_auth_credentials do
    case Application.fetch_env(@app, :service_auth_credentials_cached) do
      {:ok, current_value} ->
        current_value
      :error ->
        data = load_service_auth_credentials()
        Application.put_env(@app, :service_auth_credentials_cached, data, persistent: true)
        data
    end
  end


  # Load the raw configuration value, which is a comma-separated
  # string of auth tokens in the form: "hostname:username:authtoken".
  # The values are properly split and stored in a lookup Map.
  #
  defp load_service_auth_credentials do
    Logger.debug "Routemaster: loading service auth credentials"
    try do
      Application.get_env(@app, :service_auth_credentials)
      |> String.split(",")
      |> Enum.map(fn(str) ->
        [host, user, token] = String.split(str, ":")
        {host, Utils.build_auth_header(user, token)}
      end)
      |> Enum.into(%{})
    rescue _e ->
      raise "Routemaster: Invalid configuration for :service_auth_credentials"
    end
  end


  @doc """
  For the given hostname, it returns a HTTP Authorization header value.
  The hostname must be found in the credentials Map returned by
  `service_auth_credentials/0`
  """
  @spec service_auth_for(binary) :: {:ok, binary} | :error
  def service_auth_for(host) do
    case service_auth_credentials()[host] do
      nil -> :error
      auth -> {:ok, auth} 
    end
  end
end
