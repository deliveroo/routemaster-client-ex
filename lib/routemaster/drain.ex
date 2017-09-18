defmodule Routemaster.Drain do
  @moduledoc """
  The foundation of a Drain app.

  This module is meant to be `use`'d into another module to build a Drain pipeline.
  It's an extension of `Plug.Builder` and it's based on the same concepts.

  When `use`'d it takes care of the boilerplate configuration to provide the basic
  behaviour that a Drain app must implement.

  More specifically, it defines a default Plug pipeline with these plugs, in order:

  * `Routemaster.Plugs.RootPostOnly`
  * `Routemaster.Plugs.Auth`
  * `Routemaster.Plugs.Parser`
  * `Routemaster.Plugs.Terminator`

  It also automatically configures `Plug.Logger` (only with `Mix.env == :dev`) and
  `Plug.ErrorHandler` to handle some common errors raised by the plugs (e.g.
  JSON parse errors).

  That, by itself, is enough to accept and validate the event-delivery POST
  requests from the bus server and to respond with the appropriate status codes.
  To actually _process_ the received events and do something useful with them,
  this module provides its own `drain/2` macro to build a second _asynchronous_
  plug pipeline. This second plug pipeline handles the events in the background
  without blocking the HTTP response and is triggered from the main pipeline before
  returning a response. All the plugs defined with the `drain/2` macro are
  executed in a supervised `Task` linked to a `Task.Supervisor`.

  For example:

  ```
  # Define a Drain app, it will be a valid Plug.
  #
  defmodule MyApp.MyDrainApp do
    use Routemaster.Drain

    drain Routemaster.Drains.Siphon, topic: "burgers", to: MyApp.BurgerSiphon
    drain Routemaster.Drains.Dedup
    drain Routemaster.Drains.IgnoreStale
    drain :a_function_plug, some: "options"
    drain Routemaster.Drains.FetchAndCache
    drain MyApp.MyCustomDrain, some: "other options"
    drain Routemaster.Drains.Notify, listener: MyApp.EventsSink

    def a_function_plug(conn, opts) do
      {:ok, stuff} = MyApp.Utils.do_something(conn.assigns.events, opts[:some])
      Plug.Conn.assign(conn, :stuff, stuff)
    end
  end

  # Mount it into a Phoenix or Plug Router.
  #
  defmodule MyApp.Web.Router do
    use MyApp.Web, :router

    scope path: "/events" do
      forward "/", MyApp.MyDrainApp
    end
  end
  ```

  Just like with the `Plug.Builder.plug/2` macro, multiple plugs can be defined
  with the `drain/2` macro, and the plugs in the Drain pipeline will be executed
  in the order they've been added. In the example above, `Routemaster.Drains.Dedup`
  will be called first, followed by `Routemaster.Drains.IgnoreStale`, then the
  `:a_function_plug` function and so on.

  Again, the second drain pipeline is anynchronous and independent from the main
  plug pipeline. The original HTTP POST request that delivers the batch of events
  is responded to when the main plug pipeline reaches the `Terminator` plug, and
  ideally way before the second drain pipeline has completed.

  This has been done for two reasons:
  
  * To respond quickly and without errors not related to the HTTP request. An
  event-delivery request from the bus server only needs to be a POST to the correct
  path, be authenticated and with a valid JSON body containing events.
  Once all of this has been verified without errors, there is no reason to delay the
  response to the bus server, and it would be inappropriate to respond a 500 just
  because something else later in the pipeline fails to process an event.
  * With a supervised root `Task` that fans out to other independently supervised
  tasks, errors (e.g. timeouts fetching a resource) can be handled and retried
  with more flexibility.

  """

  defmacro __using__(_opts) do
    quote do
      use Plug.Builder
      alias Routemaster.Plugs
      import Routemaster.Drain, only: [drain: 1, drain: 2]

      @supervisor DrainPipelines.TaskSupervisor

      if Mix.env == :dev do
        # Only log in dev, as the host application already
        # takes care of request logging in production.
        plug Plug.Logger, log: :debug
      end

      # Invokes `handle_errors/2` callbacks to handle errors and exceptions.
      # After the callbacks are invoked the errors are re-raised.
      # Must be use'd after the debugger.
      use Plug.ErrorHandler

      plug Plugs.RootPostOnly
      plug Plugs.Auth
      plug Plugs.Parser
      plug :start_async_drains
      plug Plugs.Terminator


      @doc false
      def init(opts) do
        Application.ensure_started(:routemaster)
        super(opts)
      end


      # Start the async drains (which are plugs under a different name)
      # in an asyncronous task, then just return the conn with a no-op
      # to progress to the next "actual" plug and return a response.
      #
      @doc false
      def start_async_drains(conn, _opts) do
        # Do this _outside_ the fn passed to the task, to limit the
        # amount of data passed between processes.
        light_conn = strip_conn_data(conn)

        Task.Supervisor.start_child(@supervisor, fn() ->
          # Start the async drain plug pipeline. This will return a
          # processed conn that we can discard.
          _start_async_drains(light_conn, [])
        end)

        conn
      end


      # At this point `conn` contains multiple references to the same event
      # payload and other data that is not really needed in the async drain
      # pipeline. Since passing a lot of data between processes is expensive,
      # here we strip the conn to make it lighter before passing it to the
      # async task.
      #
      defp strip_conn_data(conn) do
        %{
          conn |
          params: %{}, body_params: %{}, before_send: [],
          cookies: %{}, req_cookies: %{}, req_headers: [],
          resp_headers: [], adapter: {Plug.MissingAdapter, nil},
          halted: false, host: "", method: "", port: 0,
        }
      end


      # Either:
      #  - Plug.Parsers.UnsupportedMediaTypeError
      #    The request content-type is not JSON.
      #    Status: 415
      #  - Plug.Parsers.ParseError
      #    The request body is not valid JSON
      #    Status: 400
      #
      # This should not normally happen, and it's ok to handle this
      # with an exception despite the performance hit. The alternative,
      # that is being defensive and checking the content-type for each
      # request, is likely going to have a higher performance impact.
      #
      defp handle_errors(conn, %{kind: :error, reason: %{plug_status: status}, stack: _}) do
        send_resp(conn, status, "")
      end
      defp handle_errors(conn, _), do: conn


      Module.register_attribute(__MODULE__, :drains, accumulate: true)
      @before_compile Routemaster.Drain
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    drains = Module.get_attribute(env.module, :drains)
    {conn, drain_pipeline} = Plug.Builder.compile(env, drains, [])

    # Define the function that will start the async drain plug pipeline.
    # The return value of this will be a Plug.Conn, which will be discarded.
    quote do
      defp _start_async_drains(unquote(conn), _), do: unquote(drain_pipeline)
    end
  end


  @doc """
  A macro that stores a new plug for the Drain pipeline. The `opts` will be
  passed unchanged to the new plug.

  ## Examples

      drain Routemaster.Drains.Dedup # module plug
      drain :foo, some_options: true # function plug

  """
  defmacro drain(drain_module, opts \\ []) do
    quote do
      # This must be compatible with the plug specification
      @drains {unquote(drain_module), unquote(opts), true}
    end
  end
end
