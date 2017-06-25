alias Routemaster.Redis
alias Routemaster.Config
alias Routemaster.Cache
alias Routemaster.Drain.App, as: DrainApp

drain_server = fn() ->
  {:ok, _} = Plug.Adapters.Cowboy.http DrainApp, []
end
