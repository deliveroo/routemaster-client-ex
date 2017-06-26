alias Routemaster.Redis
alias Routemaster.Config
alias Routemaster.Cache

drain_server = fn() ->
  {:ok, _} = Plug.Adapters.Cowboy.http(Routemaster.Drain.App, [])
end
