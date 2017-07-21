defmodule Routemaster.Fetcher do
  @moduledoc """
  API client to fetch resources linked to from the events.
  """

  # Do not import any HTTP-verb function
  use Tesla, docs: false, only: []

  alias Routemaster.Config

  adapter Tesla.Adapter.Hackney, Config.fetcher_http_options

  # Make this the outermost middleare to calculate the timing
  # for the entire stack.
  #
  unless Mix.env == :test do
    plug Tesla.Middleware.Logger
  end

  plug :authenticate!
  plug Tesla.Middleware.Retry, delay: 100, max_retries: 2
  plug Tesla.Middleware.DecodeJson
  plug Tesla.Middleware.Headers, %{"user-agent" => Config.user_agent}

  # If enabled, this must be the innermost middleware in order
  # to log all request headers and the raw response body.
  #
  # plug Tesla.Middleware.DebugLogger


  @doc """
  GETs a resource at a give URL.
  It expects all URLs and services to require an Authorization HTTP header,
  and it will raise an exception if no auth credentials can be found for
  a given URL.
  """
  def get(url) do
    case request(method: :get, url: url) do
      %{status: 200, body: body, headers: _headers} ->
        {:ok, body}
      %{status: status} ->
        {:error, status}
    end
  end


  @doc """
  Dynamic middleware. Adds a HTTP Basic auth header for the current
  host. It raises an exception if there are no credentials configured
  for a host.
  """
  def authenticate!(env, next) do
    env
    |> do_authenticate!
    |> Tesla.run(next)
  end


  defp do_authenticate!(env) do
    %{host: host} = URI.parse(env.url)

    auth_header = 
      case Config.service_auth_for(host) do
        {:ok, auth} ->
          %{"Authorization" => auth}
        :error ->
          raise "Unknown credentials for #{host}"
      end

    Map.update!(env, :headers, &Map.merge(&1, auth_header))
  end
end
