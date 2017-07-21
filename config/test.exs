use Mix.Config

config :logger, level: :error

config :bypass, test_framework: :espec

config :routemaster, :redis_cache, [database: 5]
config :routemaster, :redis_data, [database: 6]

config :routemaster, :api_token, "a-test-api-token"
config :routemaster, :drain_token, "a-test-drain-token"
config :routemaster, :bus_url, "http://localhost:4567"
config :routemaster, :drain_url, "http://drain-url.local/events"

config :routemaster, :service_auth_credentials, "localhost:a-user:a-token,foobar.local:name:secret"

# Use very high timeouts in the test environment so that
# it's easier to add breakpoints.
#
# config :routemaster, :director_http_options,
#   [{:recv_timeout, 300_000}, {:connect_timeout, 300_000}]
#
# config :routemaster, :publisher_http_options,
#   [{:recv_timeout, 300_000}, {:connect_timeout, 300_000}]
#
# config :routemaster, :fetcher_http_options,
#   [{:recv_timeout, 5_000}, {:connect_timeout, 8_000}]
