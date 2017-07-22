defmodule Routemaster.Topic do
  @moduledoc """
  Utility functions to validate topic names.
  """

  @format ~r/^[a-z_]{1,64}$/

  @doc """
  Checks if a string is a valid topic name. Returns a boolean.
  """
  @spec valid_name?(binary) :: boolean
  def valid_name?(name) do
    Regex.match? @format, name
  end


  @doc """
  Validates a topic name, raises a `Routemaster.Topic.InvalidNameError`
  exception if invalid.
  """
  @spec validate_name!(binary) :: nil
  def validate_name!(name) do
    unless valid_name?(name) do
      raise __MODULE__.InvalidNameError, name
    end
  end


  defmodule InvalidNameError do
    @moduledoc false
    defexception [:message]

    def exception(name) do
      msg = "invalid topic name #{inspect name}."
      %__MODULE__{message: msg}
    end
  end
end
