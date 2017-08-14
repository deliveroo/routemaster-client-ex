defmodule Routemaster.DummyService do
  @moduledoc """
  A dummy service to help in development.

  It's meant to simualate a remote service from which resources
  can be fetched. This would be an event-producer or resource
  owner in a production environment.

  It listens on localhost:4242 and responds to any request with
  a HTTP status 200 and a JSON body with some data from the
  request plus a fake `updated_at` timestamp.
  """

  require Logger
  use Plug.Builder

  @doc """
  Starts the dummy service server on localhost:4242.
  """
  def run do
    Plug.Adapters.Cowboy.http(__MODULE__, [], port: 4242)
  end


  @doc false
  def call(conn, opts) do
    conn
    |> log_request_time()
    |> super(opts)
    |> put_resp_content_type("application/json")
    |> send_resp(200, echo_response(conn))
  end


  defp echo_response(conn) do
    Poison.encode! %{
      "headers" => headers_map(conn),
      "path" => conn.request_path,
      "method" => conn.method,
      "updated_at" => random_time_ago(),
    }
  end


  # Collect the request headers in a serializable map.
  # Preserve headers with multiple values.
  #
  defp headers_map(conn) do
    Enum.reduce conn.req_headers, %{}, fn({k, v}, acc) ->
      Map.update acc, k, [v], &[v | &1]
    end
  end


  defp random_time_ago do
    DateTime.utc_now |> DateTime.to_iso8601
  end


  # ----------------------------------------------------------------
  # shamelessly borrowed from `Plug.Logger`
  #
  defp log_request_time(conn) do
    start = System.monotonic_time()

    Plug.Conn.register_before_send(conn, fn conn ->
      Logger.debug fn ->
        stop = System.monotonic_time()
        diff = System.convert_time_unit(stop - start, :native, :micro_seconds)

        [
          IO.ANSI.magenta(),
          "[DummyService] ", conn.method, ?\s, conn.request_path, " - Sent ",
          Integer.to_string(conn.status), " in ", formatted_diff(diff),
          IO.ANSI.reset()
        ]
      end
      conn
    end)
  end
  #
  defp formatted_diff(diff) when diff > 1000, do: [diff |> div(1000) |> Integer.to_string, "ms"]
  defp formatted_diff(diff), do: [Integer.to_string(diff), "µs"]
  # ----------------------------------------------------------------
end

