defmodule Routemaster.Config do
  @moduledoc false
  @default_redis_config [
    host: "localhost",
    port: 6379,
    database: 0,
  ]

  @doc """
  Returns the connection condfiguration for Redis.
  It could be either a Keyword List of parameters or a
  binary URI.
  """
  def redis_config do
    case Application.get_env(:routemaster, :redis, []) do
      uri  when is_binary(uri) ->
        uri
      opts when is_list(opts) ->
        Keyword.merge(@default_redis_config, opts)
    end
  end
end
