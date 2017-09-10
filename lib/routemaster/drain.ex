defmodule Routemaster.Drain do
  @moduledoc """
  The basis of a Drain app.

  This module is meant to be `use`'d into another module to build a Drain pipeline.

  It's an extension of `Plug.Builder` and provides its own macro `drain/2`.


  ```
  # Define a Drain app, it will be a valid Plug.
  #
  defmodule MyApp.MyDrainApp do
    use Routemaster.Drain

    drain Drain.Plugs.Dedup
    drain Drain.Plugs.IgnoreStale
    drain Drain.Plugs.FetchAndCache
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
  """

  defmacro __using__(_opts) do
    quote do
      use Plug.Builder
      alias Routemaster.Drain
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

      plug Drain.Plugs.RootPostOnly

      plug Drain.Plugs.Auth

      # Parse JSON bodies and automatically reject non-JSON requests with a 415 response.
      plug Drain.Plugs.Parser

      plug :start_async_drains

      plug Drain.Plugs.Terminator

      @doc false
      def init(opts) do
        Application.ensure_started(:routemaster)
        super(opts)
      end

      # Make the compile-time options available to each request.
      # This allows to customize some nested module with options
      # passed to the public drain app.
      #
      # Available data:
      #  - conn.assigns.events
      #  - conn.assigns.drain_opts
      #
      @doc false
      def call(conn, opts) do
        conn
        |> assign(:drain_opts, opts)
        |> super(opts)
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
          params: nil, body_params: nil, before_send: nil,
          cookies: nil, req_cookies: nil, req_headers: [],
          resp_headers: [],
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

    # IO.puts "@drains: #{inspect drains}"

    {conn, drain_pipeline} = Plug.Builder.compile(env, drains, [])

    quote do
      defp _start_async_drains(unquote(conn), _), do: unquote(drain_pipeline)
    end
  end


  @doc """
  Register a new Drain module.
  """
  defmacro drain(drain_module, opts \\ []) do
    quote do
      # This must be compatible with the plug specification
      @drains {unquote(drain_module), unquote(opts), true}
    end
  end
end
