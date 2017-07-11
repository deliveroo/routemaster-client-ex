defmodule Routemaster.Director do
  @moduledoc """
  The Director module provides functions to interact with the Routemaster
  event bus REST API. It's a client and each function will perform an
  authenticated HTTP request to the even bus server.
  """

  use Tesla, docs: false

  adapter Tesla.Adapter.Hackney

  # Make this the outermost middleare to calculate the timing
  # for the entire stack.
  #
  plug Tesla.Middleware.Logger

  plug Routemaster.Middleware.BaseUrl
  plug Routemaster.Middleware.BasicAuth
  plug Tesla.Middleware.Retry, delay: 100, max_retries: 2
  plug Tesla.Middleware.JSON

  # If enabled, this must be the innermost middleware in order
  # to log all request headers and the raw response body.
  #
  # plug Tesla.Middleware.DebugLogger


  @doc ~S"""
  Retrieves the current topics from the server and their metadata.
  It performs a `GET /topics` request.

  Example: 

      case Director.topics() do
        %{status: 200, body: topics} ->
          IO.puts "The bus is handling #{length topics} topics"
          {:ok, topics}
        %{status: status} ->
          {:error, status}
      end
  """
  def topics do
    get("/topics")
  end
end
