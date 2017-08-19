alias Routemaster.Config
alias Routemaster.Utils
alias Routemaster.Redis
alias Routemaster.Cache
alias Routemaster.Fetcher
alias Routemaster.Publisher
alias Routemaster.Director

if Mix.env == :dev do
  # Starts a local echo service to simulate a remote service.
  # The echo service will accept traffic on http://localhost:4242
  {:ok, _} = Routemaster.DummyService.start()
end
