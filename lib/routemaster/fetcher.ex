defmodule Routemaster.Fetcher do
  @moduledoc """
  API client to fetch resources linked to from the events.
  """

  @type http_status :: non_neg_integer

  # Do not import any HTTP-verb function
  use Tesla, docs: false, only: []

  alias Routemaster.Config
  alias Routemaster.Fetcher

  adapter Tesla.Adapter.Hackney, Config.fetcher_http_options

  # Make this the outermost middleare to calculate the timing
  # for the entire stack.
  #
  unless Mix.env == :test do
    plug Routemaster.Middleware.Logger, context: "Fetcher"
  end

  plug Tesla.Middleware.Headers, %{"accept" => "application/json"}

  plug Fetcher.Caching
  plug Fetcher.ServiceAuth

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

  ## Options

  - `cache` (boolean): whether the cache should be checked before the
  request and populated after the request. Defaults to `true`, set this
  to `false` to entirely skip the cache layer.
  """
  @spec get(binary, Keyword.t) :: {:ok, any} | {:error, http_status}
  def get(url, options \\ []) do
    opts = [cache: Keyword.get(options, :cache, true)]

    case request(method: :get, url: url, opts: opts) do
      %{status: 200, body: body, headers: _headers} ->
        {:ok, body}
      %{status: status} ->
        {:error, status}
    end
  end
end
