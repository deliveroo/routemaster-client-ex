defmodule Routemaster.Redis do
  @moduledoc """
  This is the main interface to Redis.

  Supported Redis commands should be implemented as public
  functions of this module.
  """

  @conn __MODULE__
  @conn_options [name: @conn, sync_connect: false]
  @prefix "rm:"

  alias Routemaster.Config

  @doc false
  def worker_spec do
    import Supervisor.Spec, only: [worker: 3]
    worker(Redix, [Config.redis_config(), @conn_options], [restart: :permanent])
  end


  def get(key) do
    Redix.command @conn, ["GET", ns(key)]
  end

  def set(key, value) do
    Redix.command @conn, ["SET", ns(key), value]
  end

  def setex(key, seconds, value) do
    Redix.command @conn, ["SETEX", ns(key), seconds, value]
  end

  def ttl(key) do
    Redix.command @conn, ["TTL", ns(key)]
  end

  def del(keys) when is_list(keys) do
    key_list = Enum.map(keys, &ns/1)
    Redix.command @conn, ["DEL" | key_list]
  end

  def del(key) do
    Redix.command @conn, ["DEL", ns(key)]
  end

  # Namespace keys
  #
  defp ns(base) do
    @prefix <> to_string(base)
  end
end
