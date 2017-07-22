defmodule Routemaster.Publisher do
  @moduledoc """
  Publishes events to the event bus.
  """

  @type http_status :: non_neg_integer

  use Tesla, docs: false, only: [:post]

  alias Routemaster.Topic
  alias Routemaster.Config
  alias Routemaster.Utils
  alias Routemaster.Publisher.Event

  adapter Tesla.Adapter.Hackney, Config.publisher_http_options

  # Make this the outermost middleare to calculate the timing
  # for the entire stack.
  #
  unless Mix.env == :test do
    plug Tesla.Middleware.Logger
  end

  plug Routemaster.Middleware.BaseUrl
  plug Routemaster.Middleware.BasicAuth
  plug Tesla.Middleware.Retry, delay: 100, max_retries: 2
  plug Tesla.Middleware.EncodeJson
  plug Tesla.Middleware.Headers, %{"user-agent" => Config.user_agent}

  # If enabled, this must be the innermost middleware in order
  # to log all request headers and the raw response body.
  #
  # plug Tesla.Middleware.DebugLogger


  @event_types ~w(create update delete noop)

  Enum.each @event_types, fn(event) ->
    @doc """
    Shortcut function to publish `#{event}` events.

    See `Routemaster.Publisher.send_event/4` for details on the arguments
    and options.
    """
    @spec unquote(String.to_atom(event))(binary, binary, Keyword.t) :: :ok | {:error, http_status}
    def unquote(String.to_atom(event))(topic, url, options \\ []) do
      send_event topic, unquote(event), url, options
    end
  end


  @doc """
  Publishes an event to the bus.

  ## Arguments:

  * `topic`: the topic to which the event should be published.
  * `event`: the event type, must be one of the canonical types: `#{Enum.join(@event_types, ", ")}`.
  * `url`: a HTTPS URL at which the resource of the event can be retrieved.
  * options, an optional keyword list with:
    * `timestamp`: an integer unix timestamp.
    * `data`: any extra payload for the event, must be serializable as JSON.

  """
  @spec send_event(binary, binary, binary, Keyword.t) :: :ok | {:error, http_status}
  def send_event(topic, event, url, options \\ [timestamp: nil, data: nil]) do
    Topic.validate_name! topic
    # Set the timestamp early, if missing. This will ensure that it's set
    # close to the actual event generation time even if the rest of this
    # function is made async. The timestamp generation should not be made
    # async, needless to say.
    time = options[:timestamp] || Utils.now()

    payload = Event.build(event, url, time, options[:data])
    Event.validate!(payload)

    case post("/topics/#{topic}", payload) do
      %{status: 200} ->
        :ok
      %{status: status} ->
        {:error, status}
    end
  end
end
