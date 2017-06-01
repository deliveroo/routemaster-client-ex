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
    Redix.command @conn, ["GET", key(key)]
  end

  def set(key, value) do
    Redix.command @conn, ["SET", key(key), value]
  end


  defp key(base) do
    @prefix <> to_string(base)
  end
end
