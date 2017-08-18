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

  alias Plug.Conn
  alias Routemaster.Config
  alias Routemaster.Utils


  plug :log_request
  plug :authenticate
  plug :respond


  @doc """
  Starts the dummy service server on localhost:4242.
  """
  def start do
    Plug.Adapters.Cowboy.http(__MODULE__, [], port: 4242)
  end


  defp respond(conn = %{state: :sent}, _opts), do: conn
  defp respond(conn, _opts) do
    conn
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
    (Utils.now - Enum.random(5..100))
    |> DateTime.from_unix!
    |> DateTime.to_iso8601
  end


  # Don't bother doing a base64-decode. Just compare the
  # encoded values.
  #
  defp authenticate(conn, _opts) do
    # this will either be 127.0.0.1 or localhost
    {:ok, auth} = Config.service_auth_for(conn.host)

    case Conn.get_req_header(conn, "authorization") do
      [^auth] ->
        conn
      _ ->
        conn
        |> Conn.put_resp_header("www-authenticate", "Basic")
        |> Conn.send_resp(401, "")
        |> Conn.halt()
    end
  end


  # ----------------------------------------------------------------
  # shamelessly borrowed from `Plug.Logger`
  #
  defp log_request(conn, _opts) do
    start = System.monotonic_time()

    Conn.register_before_send(conn, fn conn ->
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
