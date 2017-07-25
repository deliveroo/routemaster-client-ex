defmodule Routemaster.Drain.Plugs.Auth do
  @moduledoc false

  alias Routemaster.Config
  alias Plug.Conn
  require Logger


  def init(opts), do: opts


  def call(conn, _opts) do
    with {:ok, header} <- get_auth_header(conn),
          {:ok, token} <- extract_token(header),
                   :ok <- authenticate!(token) do
      conn
    else
      {:error, status} ->
        fail!(conn, status)
    end
  end


  defp get_auth_header(conn) do
    case Conn.get_req_header(conn, "authorization") do
      [value] ->
        {:ok, value}
      [] ->
        _missing_auth!()
    end
  end


  defp extract_token("Basic " <> token) do
    case Base.decode64(token) do
      {:ok, string} ->
        [token | _] = String.split(string, ":")
        {:ok, token}
      :error ->
        _invalid_auth!()
    end
  end

  defp extract_token(_), do: _invalid_auth!()


  defp authenticate!(token) do
    if Config.drain_token == token do
      :ok
    else
      _failed_auth!()
    end
  end


  defp _missing_auth! do
    Logger.info "Routemaster.Drain: event delivery request without authentication (401, unauthorized)."
    {:error, 401}
  end


  defp _invalid_auth! do
    Logger.info "Routemaster.Drain: event delivery request with invalid authentication (401, unauthorized)."
    {:error, 401}
  end


  defp _failed_auth! do
    Logger.info "Routemaster.Drain: event delivery request with unrecognized authentication (403, forbidden)."
    {:error, 403}
  end


  defp fail!(conn, 401) do
    conn
    |> Conn.put_resp_header("www-authenticate", "Basic")
    |> Conn.send_resp(401, "")
    |> Conn.halt()
  end


  defp fail!(conn, 403) do
    conn
    |> Conn.send_resp(403, "")
    |> Conn.halt()
  end
end
