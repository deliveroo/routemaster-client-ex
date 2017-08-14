alias Routemaster.Config
alias Routemaster.Utils
alias Routemaster.Redis
alias Routemaster.Cache
alias Routemaster.Fetcher
alias Routemaster.Publisher
alias Routemaster.Director

# Starts a local echo service to simlate a remote service.
#
dummy_service_server = fn() ->
  {:ok, _} = Routemaster.DummyService.run()
end

dummy_service_server.()
