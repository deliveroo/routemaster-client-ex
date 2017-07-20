defmodule Routemaster.Utils do
  @moduledoc """
  Utility functions.
  """

  @doc """
  Returns the current time as a unix timestamp.
  """
  def now do
    DateTime.utc_now() |> DateTime.to_unix()
  end


  @doc """
  Checks that a URL is valid and has a HTTPS scheme.
  """
  def valid_url?(url) do
    case URI.parse(url) do
      %URI{scheme: "https"} -> true
      _ -> false
    end
  end


  @doc """
  Returns a HTTP Authorization header Map from
  the provided plaintext username and password.
  """
  def build_auth_header(username, password) do
    token = Base.encode64(username <> ":" <> password)
    %{"Authorization" => "Basic #{token}"}
  end
end
