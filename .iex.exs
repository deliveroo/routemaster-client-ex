alias Routemaster.Config
alias Routemaster.Utils
alias Routemaster.Redis
alias Routemaster.Cache
alias Routemaster.Fetcher
alias Routemaster.Publisher
alias Routemaster.Director

if Mix.env == :dev do
  # Starts a local echo service to simlate a remote service.
  {:ok, _} = Routemaster.DummyService.start()
end
