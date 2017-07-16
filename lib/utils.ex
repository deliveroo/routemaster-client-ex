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


  def valid_url?(url) do
    case URI.parse(url) do
      %URI{scheme: "https"} -> true
      _ -> false
    end
  end
end
