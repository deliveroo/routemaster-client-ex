defmodule Routemaster.TestUtils do
  @redis Routemaster.Redis

  def clear_redis_test_db do
    Redix.command!(@redis, ["KEYS", "rm:*"])
    |> delete_keys()
  end

  defp delete_keys([]), do: 0
  defp delete_keys(keys) do
    Redix.command!(@redis, ["DEL" | keys])
  end
end
