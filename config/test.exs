use Mix.Config

config :logger, level: :error

config :bypass, test_framework: :espec

config :routemaster_client, :redis_cache, [database: 5]
config :routemaster_client, :redis_data, [database: 6]

config :routemaster_client, :bus_api_token, "a-test-api-token"
config :routemaster_client, :drain_token, "a-test-drain-token"
config :routemaster_client, :bus_url, "http://localhost:4567"
config :routemaster_client, :drain_url, "http://drain-url.local/events"

config :routemaster_client, :service_auth_credentials, "localhost:a-user:a-token,foobar.local:name:secret"

# Use very high timeouts in the test environment so that
# it's easier to add breakpoints.
#
# config :routemaster_client, :director_http_options,
#   [{:recv_timeout, 300_000}, {:connect_timeout, 300_000}]
#
# config :routemaster_client, :publisher_http_options,
#   [{:recv_timeout, 300_000}, {:connect_timeout, 300_000}]
#
# config :routemaster_client, :fetcher_http_options,
#   [{:recv_timeout, 5_000}, {:connect_timeout, 8_000}]
