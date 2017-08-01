# mix run bench/benchee.exs

term = Routemaster.Fetcher.get("https://test.deliveroo.co.uk/api/internal/orders/19123123")
key = "foobar"

Benchee.run(
  %{
    # "serialize_0" => fn() ->
    #   Routemaster.Cache.serialize_0(term)
    # end,
    # "serialize_1" => fn() ->
    #   Routemaster.Cache.serialize_1(term)
    # end,
    # "serialize_9" => fn() ->
    #   Routemaster.Cache.serialize_9(term)
    # end,

    "write_0" => fn() ->
      Routemaster.Cache.write_0(key, term)
    end,
    "write_1" => fn() ->
      Routemaster.Cache.write_1(key, term)
    end,
    "write_9" => fn() ->
      Routemaster.Cache.write_9(key, term)
    end,

    "write_read_0" => fn() ->
      Routemaster.Cache.write_0(key, term)
      Routemaster.Cache.read(key)
    end,
    "write_read_1" => fn() ->
      Routemaster.Cache.write_1(key, term)
      Routemaster.Cache.read(key)
    end,
    "write_read_9" => fn() ->
      Routemaster.Cache.write_9(key, term)
      Routemaster.Cache.read(key)
    end,
  },
  time: 10,
  formatters: [
    &Benchee.Formatters.HTML.output/1,
    &Benchee.Formatters.Console.output/1
  ],
  formatter_options: [html: [file: "bench/out/index.html"]],
)
