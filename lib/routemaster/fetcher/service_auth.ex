defmodule Routemaster.Fetcher.ServiceAuth do
  @moduledoc """
  Service authentication middleware.

  For each HTTP request to fetch remote entities, it looks up
  the authentication credentials for the host of the requested
  URL and sets it as the HTTP Authorization header of the request.

  It raises a `MissingCredentialsError` if there are no
  credentials configured for a host.
  """

  alias Routemaster.Config


  def call(env, next, _options) do
    env
    |> authenticate!
    |> Tesla.run(next)
  end


  defp authenticate!(env) do
    %{host: host} = URI.parse(env.url)
    auth_header = lookup_credentials!(host)
    Map.update!(env, :headers, &Map.merge(&1, auth_header))
  end


  defp lookup_credentials!(host) do
    case Config.service_auth_for(host) do
      {:ok, auth} ->
        %{"Authorization" => auth}
      :error ->
        raise __MODULE__.MissingCredentialsError, host
    end
  end


  defmodule MissingCredentialsError do
    @moduledoc false
    defexception [:message]

    def exception(hostname) do
      msg = "Can't find auth credentials for host: #{hostname}"
      %__MODULE__{message: msg}
    end
  end
end
