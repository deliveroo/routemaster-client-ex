defmodule Routemaster.Middleware.Logger do
  @moduledoc """
  A reimplementation of the default `Tesla.Middleware.Logger`
  ([source](https://github.com/teamon/tesla/blob/v0.7.1/lib/tesla/middleware/logger.ex)).

  This middleware logs outgoing requests with extra metadata.
  """
  require Logger

  def call(env, next, opts) do
    {micro_s, env} = :timer.tc(Tesla, :run, [env, next])
    log_request(env, micro_s, opts)
    env
  rescue
    ex in Tesla.Error ->
      stacktrace = System.stacktrace()
      _ = log_error(env, ex, opts[:context])
      reraise ex, stacktrace
  end


  defp log_error(env, %{message: message}, context) do
    Logger.error fn ->
      "[#{context}] #{normalize_method(env)} #{env.url} -> #{message}"
    end
  end


  defp log_request(env, micro_s, opts) do
    Logger.info fn() ->
      ms = :io_lib.format("~.3f", [micro_s / 1000])
      "[#{opts[:context]}] #{normalize_method(env)} #{env.url} -> #{env.status} (#{ms}ms)"
    end
  end


  defp normalize_method(env) do
    env.method |> to_string() |> String.upcase()
  end
end
