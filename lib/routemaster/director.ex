defmodule Routemaster.Director do
  @moduledoc """
  The Director module provides functions to interact with the Routemaster
  event bus REST API. It's a client and each function will perform an
  authenticated HTTP request to the even bus server.
  """

  use Tesla, docs: false
  import Routemaster.Topic, only: [validate_name!: 1]
  alias Routemaster.Config

  adapter Tesla.Adapter.Hackney

  # Make this the outermost middleare to calculate the timing
  # for the entire stack.
  #
  unless Mix.env == :test do
    plug Tesla.Middleware.Logger
  end

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

  # Examples

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
    validate_name! name
    case all_topics() do
      {:ok, topics} ->
        topic = Enum.find(topics, fn(t) -> t["name"] == name end)
        {:ok, topic}
      error -> error
    end
  end


  @doc """
  Deletes an owned topic from the bus server.
  """
  def delete_topic(name) do
    validate_name! name
    case delete("/topics/" <> name) do
      %{status: 204} ->
        {:ok, nil}
      %{status: status} ->
        {:error, status}
    end
  end


  @doc """
  Creates a subscription on the bus server.
  Arguments:

  * `topics`: a list of valid topic names. This must always be the complete
  set of topics this subscriber wants to receive, because any missing
  previously-submitted topics will see their subscriptions deleted.
  * `callback`: a fully qualified https URL. This is where the drain will
  receive the events.
  * options (optional):
    * `max`: How many events can be batched together on delivery. The server
    will never deliver batches larger than this number. Default: 100.
    * `timeout`: How long the server can wait before delivering the events (ms).
    Once this timeout is reached, a batch is delivered even if incomplete.
    This indirectly controls the max latency of event delivery. Default: 500ms.


  # Examples

  Subscribe to two topics, and dispatch events within 2 seconds, in batches
  no larger than 300 events:

      Director.subscribe(
        ~w(users orders),
        "https://example.com/rm-events",
        max: 300,
        timeout: 2_000
      )
  """
  def subscribe(topics, callback, options \\ []) do
    Enum.each(topics, &validate_name!/1)

    data = %{
      topics: topics,
      callback: callback,
      uuid: Config.client_token,
      max: options[:max],
      timeout: options[:timeout]
    }

    case post("/subscriptions", data) do
      %{status: 204} ->
        {:ok, nil}
      %{status: status} ->
        {:error, status}
    end
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
end
