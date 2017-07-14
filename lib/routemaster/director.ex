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

      case Director.all_topics() do
        {:ok, topics} ->
          "The bus is handling #{length topics} topics"
        {:error, status} ->
          "Couldn't get topics, HTTP error #{status}"
      end
  """
  def all_topics do
    case get("/topics") do
      %{status: 200, body: topics} ->
        {:ok, topics}
      %{status: status} ->
        {:error, status}
    end
  end


  @doc """
  Returns a single topic, by name.
  It will fetch all topics over the network and filter them locally.
  """
  def get_topic(name) do
    case all_topics() do
      {:ok, topics} ->
        topic = Enum.find(topics, fn(t) -> t["name"] == name end)
        {:ok, topic}
      error -> error
    end
  end


  @doc """
  """
  def subscribe(topics, callback, options) do
    data = %{
      topics: topics,
      callback: callback,
      max: options[:max],
      timeout: options[:timeout],
    }

    post("/subscriptions", data)
  end

  @doc """
  """
  def unsubscribe(topics) when is_list(topics) do
    Enum.each topics, &unsubscribe/1
  end

  def unsubscribe(topic) do
    delete("/subscriber/topics/" <> topic)
  end


  @doc """
  """
  def unsubscribe_all do
    delete("/subscriber")
  end


  @doc """
  Deletes an owned topic from the bus server.
  """
  def delete_topic(topic) do
    case delete("/topics/" <> topic) do
      %{status: 204} ->
        {:ok, nil}
      %{status: status} ->
        {:error, status}
    end
  end
end
