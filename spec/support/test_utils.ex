defmodule Routemaster.TestUtils do
  alias Routemaster.Redis

  def clear_all_redis_test_dbs do
    [Redis.data.conn(), Redis.cache.conn()]
    |> Enum.map(fn(conn) ->
      Redix.command!(conn, ["KEYS", "rm:*"])
      |> delete_keys(conn)
    end)
  end

  def clear_redis_test_db(redis) do
    conn = redis.conn()
    Redix.command!(conn, ["KEYS", "rm:*"])
    |> delete_keys(conn)
  end

  defp delete_keys([], _conn), do: 0
  defp delete_keys(keys, conn) do
    Redix.command!(conn, ["DEL" | keys])
  end

  def now do
    DateTime.utc_now() |> DateTime.to_unix()
  end

  def make_drain_event(index) do
    ~s({"type":"update","topic":"dinosaurs","url":"https://example.com/dinosaurs/#{index}","t":#{now() - 2}})
  end
  # def make_drain_event(index, data) do
  # end
end
