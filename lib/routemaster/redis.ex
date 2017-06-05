defmodule Routemaster.Redis do
  @moduledoc """
  This is the main interface to Redis.

  Supported Redis commands should be implemented as public
  functions of this module.
  """

  # @conn __MODULE__
  # @conn_options [name: @conn, sync_connect: false]
  # @prefix "rm:"

  alias Routemaster.Config

  @doc false
  def worker_spec(type) do
    import Supervisor.Spec, only: [worker: 3]
    name = String.to_atom("rm_#{type}_redis")
    worker(Redix, [Config.redis_config(type), [name: name, sync_connect: false]], [restart: :permanent, id: name])
  end

  def data, do: __MODULE__.Data
  def cache, do: __MODULE__.Cache

  defmacro __using__(type) do
    quote do
      @prefix "rm:#{unquote(type)}:"
      @conn String.to_atom("rm_#{unquote(type)}_redis")

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
  end
end

defmodule Routemaster.Redis.Data do
  use Routemaster.Redis, :data
end

defmodule Routemaster.Redis.Cache do
  use Routemaster.Redis, :cache
end
