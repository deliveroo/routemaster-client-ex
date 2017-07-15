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
end
