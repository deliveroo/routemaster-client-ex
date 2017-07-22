defmodule Routemaster.Utils do
  @moduledoc """
  Utility functions.
  """

  @doc """
  Returns the current time as a unix timestamp.
  """
  @spec now :: non_neg_integer
  def now do
    DateTime.utc_now() |> DateTime.to_unix()
  end


  @doc """
  Checks that a URL is valid and has a HTTPS scheme.
  """
  @spec valid_url?(binary) :: boolean
  def valid_url?(url) do
    case URI.parse(url) do
      %URI{scheme: "https"} -> true
      _ -> false
    end
  end


  @doc """
  Returns a HTTP Authorization header value from
  the provided plaintext username and password.
  """
  @spec build_auth_header(binary, binary) :: binary
  def build_auth_header(username, password) do
    token = Base.encode64(username <> ":" <> password)
    "Basic #{token}"
  end
end
