use Mix.Config

config :logger, level: :error

config :routemaster, :redis_cache, [database: 5]
config :routemaster, :redis_data, [database: 6]

config :routemaster, :api_token, "a-test-api-token"
config :routemaster, :client_token, "a-test-client-token"
config :routemaster, :bus_url, "http://localhost:4567"
