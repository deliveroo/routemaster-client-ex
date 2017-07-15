use Mix.Config

config :logger, level: :error

config :bypass, framework: :espec

config :routemaster, :redis_cache, [database: 5]
config :routemaster, :redis_data, [database: 6]

config :routemaster, :api_token, "a-test-api-token"
config :routemaster, :client_token, "a-test-client-token"
config :routemaster, :bus_url, "http://localhost:4567"
config :routemaster, :drain_url, "http://drain-url.local/events"
