use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.


config :routemaster, :redis_cache,
  {:system, "REDIS_CACHE_URL", "redis://localhost:6379/0"}

config :routemaster, :redis_data,
  {:system, "REDIS_DATA_URL", "redis://localhost:6379/1"}


case Mix.env do
  :test -> import_config "test.exs"
  _     -> nil
end
