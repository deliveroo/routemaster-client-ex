# mix run bench/poison.exs

alias Routemaster.{Cache,Fetcher}

term = Fetcher.get("https://test.deliveroo.co.uk/api/internal/orders/19123123")

erl_binary_0 = Cache.serialize_0(term)
erl_binary_1 = Cache.serialize_1(term)
erl_binary_9 = Cache.serialize_9(term)
json = Poison.encode!(term)

Benchee.run(
  %{
    "serialize_0" => fn() ->
      Cache.serialize_0(term)
    end,
    "serialize_1" => fn() ->
      Cache.serialize_1(term)
    end,
    "serialize_9" => fn() ->
      Cache.serialize_9(term)
    end,

    "deserialize_0" => fn() ->
      Cache.deserialize(erl_binary_0)
    end,
    "deserialize_1" => fn() ->
      Cache.deserialize(erl_binary_1)
    end,
    "deserialize_9" => fn() ->
      Cache.deserialize(erl_binary_9)
    end,

    "poison_encode" => fn() ->
      Poison.encode!(term)
    end,
    "poison_decode" => fn() ->
      Poison.decode!(json)
    end
  },
  time: 4,
  formatters: [
    &Benchee.Formatters.HTML.output/1,
    &Benchee.Formatters.Console.output/1
  ],
  formatter_options: [html: [file: "bench/out/index.html"]],
)
