alias Routemaster.Config
alias Routemaster.Utils
alias Routemaster.Redis
alias Routemaster.Cache
alias Routemaster.Fetcher
alias Routemaster.Publisher
alias Routemaster.Director

drain_server = fn() ->
  {:ok, _} = Plug.Adapters.Cowboy.http(Routemaster.Drain.App, [])
end
