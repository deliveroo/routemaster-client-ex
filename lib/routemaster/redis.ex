defmodule Routemaster.Redis do
  @moduledoc """
  This is the main interface to Redis, and it implements two functions
  to get a reference to the two Redis stores: the persistent data store
  and the cache store.

  Supported Redis commands should be implemented as public
  functions of this module, and will automaticallt be available on both
  clients.
  """

  alias Routemaster.Config

  @doc false
  def worker_spec(type) do
    import Supervisor.Spec, only: [worker: 3]
    name = String.to_atom("rm_#{type}_redis")
    worker(
      Redix,
      [Config.redis_config(type), [name: name, sync_connect: false]],
      [restart: :permanent, id: name]
    )
  end


  @doc """
  Returns a redis connection to the persistent Redis store. The returned
  term can be used to issue Redis commands.

      iex> Routemaster.Redis.data.set(:foo, "bar")
      {:ok, "OK"}
      iex> Routemaster.Redis.data.get(:foo)
      {:ok, "bar"}
  """
  @spec data :: __MODULE__.Data
  def data, do: __MODULE__.Data


  @doc """
  Returns a redis connection to the cache Redis store. The returned
  term can be used to issue Redis commands.

      iex> Routemaster.Redis.cache.set(:foo, "bar")
      {:ok, "OK"}
      iex> Routemaster.Redis.cache.get(:foo)
      {:ok, "bar"}
  """
  @spec cache :: __MODULE__.Cache
  def cache, do: __MODULE__.Cache


  @doc """
  Serializes an Elixir term into a binary using Erlang's
  [External Term Format](http://erlang.org/doc/apps/erts/erl_ext_dist.html).

  The returned binary can be safely stored into Redis and
  deserialized later.
  """
  @spec serialize(term) :: binary
  def serialize(term) do
    :erlang.term_to_binary(term, compressed: 1)
  end

  @doc """
  Deserializes valid binary data (External Term Format)
  back into an Elixir term.
  """
  @spec deserialize(binary) :: term
  def deserialize(data) do
    :erlang.binary_to_term(data)
  end


  defmacro __using__(type) do
    quote do
      @prefix "rm:#{unquote(type)}:"
      @conn String.to_atom("rm_#{unquote(type)}_redis")

      @doc false
      def conn, do: @conn

      def get(key) do
        Redix.command @conn, ["GET", ns(key)]
      end

      def mget(keys) when is_list(keys) do
        Redix.command @conn, ["MGET" | ns_all(keys)]
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
        Redix.command @conn, ["DEL" | ns_all(keys)]
      end

      def del(key) do
        Redix.command @conn, ["DEL", ns(key)]
      end

      # Namespace keys
      #
      defp ns(base) do
        @prefix <> to_string(base)
      end

      defp ns_all(list) do
        Enum.map(list, &ns/1)
      end
    end
  end
end

defmodule Routemaster.Redis.Data do
  @moduledoc """
  This module provides access to the persistent data store Redis.

  Access it through `Routemaster.Redis.data()`.
  """
  use Routemaster.Redis, :data
end

defmodule Routemaster.Redis.Cache do
  @moduledoc """
  This module provides access to the cache Redis.

  Access it through `Routemaster.Redis.cache()`.
  """
  use Routemaster.Redis, :cache
end
