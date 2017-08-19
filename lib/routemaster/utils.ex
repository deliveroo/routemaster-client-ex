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


  @doc """
  Returns a formatted and ANSI-escaped string, useful to
  produce consistent color coded log messages in development.

  
  For example, this code:

      Logger.debug fn() ->
        Utils.debug_message(
          "My Context",
          ["A string", ["or", "a"], "IO-list"],
          :red
        )
      end

  Will produce this logger output in the terminal, with the
  formatted message coloured in red:

  ```text
  10:00:42.123 [debug] [My Context] A string or a IO-list
  ```
  """
  @spec debug_message(iodata, iodata, atom) :: iodata
  def debug_message(title, message, color) do
    [color, :bright, "[", title, "]", :normal, ?\s, message, :reset]
    |> IO.ANSI.format()
  end
end
