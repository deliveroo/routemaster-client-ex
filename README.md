# Routemaster Client

[![Build Status](https://travis-ci.org/deliveroo/routemaster-client-ex.svg?branch=master)](https://travis-ci.org/deliveroo/routemaster-client-ex)
[![Hex.pm](https://img.shields.io/hexpm/v/routemaster_client.svg)](https://hex.pm/packages/routemaster_client)
[![hexdocs.pm](https://img.shields.io/badge/docs-0.1.0-brightgreen.svg)](https://hexdocs.pm/routemaster_client)

This Elixir package is a client for the [Routemaster](https://github.com/deliveroo/routemaster) event bus server application. It's a port of the Ruby clients, [routemaster-drain](https://github.com/deliveroo/routemaster-drain) and [routemaster-client](https://github.com/deliveroo/routemaster-client).

## Content

* [Project Organization](#project-organization)
* [Configuration](#configuration)
* [Core Functionality](#core-functionality)
    - [Subscribe to Topics](#subscribe-to-topics)
    - [Receive Events With a Drain Plug](#receive-events-with-a-drain-plug)
    - [Publish Events](#publish-events)
    - [Fetch Remote Resources](#fetch-remote-resources)
* [Installation](#installation)
* [Dependencies](#dependencies)
    - [Redis](#redis)
* [Development Setup](#development-setup)
    - [Install an Elixir Environment](#install-an-elixir-environment)
    - [Install Redis](#install-redis)
    - [Setup the Project](#setup-the-project)
    - [Development Tools](#development-tools)
    - [Run](#run)
        + [Start Redis](#start-redis)
        + [Terminal Commands](#terminal-commands)
        + [The Dummy Local Service](#the-dummy-local-service)
* [Test](#test)


## Project Organization

The package is organized in four main functional areas:

* `Routemaster.Drain`, a [Plug](https://github.com/elixir-lang/plug) app builder to set up endpoints to receive events over HTTP.
* `Routemaster.Fetcher`, a HATEOAS API client to get entities from other services.
* `Routemaster.Publisher`, a module to publish events to the event bus.
* `Routemaster.Director`, an interface to subscribe to topics, unsubscribe, list and delete (owned) topics, and in general interact with the API of the server.

A fifth private component is `Routemaster.Cache`, used by the `Fetcher` to store retrieved resources and busted by the `Drain` when new data becomes available.

## Configuration

This library is configured with [`Mix.Config`](https://hexdocs.pm/mix/Mix.Config.html#content). The [`Config` module](https://github.com/deliveroo/routemaster-client-ex/blob/master/lib/routemaster/config.ex) is the authoritative source of truth for the supported configuration options.

An example:

```elixir
use Mix.Config

# The Redis instances used for cache and data
config :routemaster,
  redis_cache: "redis://redis.host.one:6379/0",
  redis_data: "redis://redis.host.two:6379/0"

# or
config :routemaster,
  redis_cache: [host: "redis.host.one", port: 6379, database: 0],
  redis_data: [host: "redis.host.two", port: 6379, database: 0]

config :routemaster, :cache_ttl, "86400"

config :routemaster,
  bus_url: "https://routemaster.server",
  bus_api_token: "bus-server-api-token",
  drain_url: "https://myapp.url/events",
  drain_token: "my-app--drain-auth-token"

config :routemaster,
  :service_auth_credentials,
  "example.com:username:auth-token,otherapp.url:other-username:other-auth-token"
```


This library optionally supports Phoenix-style system tuples to dynamically read its configuration from the environment, which means that it can be configured at runtime (on boot) rather than at compile-time.

While using the environment is optional, it's the recommended way to configure a [12-factor application](https://12factor.net/) and it allows to reuse the compiled artifacts with different configurations. When using this library in a project, in order to read the configuration from the environment you must declare the optional dependency [`deferred_config`](https://github.com/mrluc/deferred_config) in the project mix file.

As a demonstration, when [working locally on this library](#development-setup) the development setup relies on the environment to configure the project. The included [`config.exs`](https://github.com/deliveroo/routemaster-client-ex/blob/master/config/config.exs) file (only applies in dev for this repo) is an example of how to set options using the environment, and the [`bin/_env.example`](https://github.com/deliveroo/routemaster-client-ex/blob/master/bin/_env.example) file shows how those variables are supposed to be set.

## Core Functionality

### Subscribe to Topics

The `Director` module provides functions to subscribe to and work with topics. First, you must configure the application in your Mix config file:

```elixir
use Mix.Config

config :routemaster,
  bus_url: "https://routemaster.server",
  bus_api_token: "bus-server-api-token",
  drain_url: "https://myapp.url/events",
  drain_token: "my-app--drain-auth-token"
```

And then:

```elixir
# Subscribe to two topics
Routemaster.Director.subscribe(["avocados", "bananas"])

# The same, but with max 100 events per batch and max batch latency of 150ms
Routemaster.Director.subscribe(["avocados", "bananas"], max: 100, timeout: 150)

# Unsubscribe from one or all topics
Routemaster.Director.unsubscribe("bananas")
Routemaster.Director.unsubscribe_all()

# Get info on the topics
Routemaster.Director.all_topics()
Routemaster.Director.get_topic("pears")

# Delete owned topics
Routemaster.Director.delete_topic("pears")

# Get info on the subscribers
Routemaster.Director.all_subscribers()
```


### Receive Events With a Drain Plug

The Routemaster event bus delivers events over HTTP. Once an event consumer app is subscribed to the bus, event batches for the selected topics are delivered as JSON with authenticated POST requests to the specified endpoint. This library provides conveniencies and utilities to create and configure event receiver endpoints and the event handlers that sit behind them, commonly referred to as a "Routemaster Drains".

The HTTP endpoints are built as [Plugs](https://hex.pm/packages/plug), which makes them easily embeddable in their host Phoenix or generic Plug applications. The event handling pipelines are built on the same concepts.

For example, a Drain app can be defined as:

```elixir
defmodule MyApp.MyDrainApp do
  use Routemaster.Drain

  drain Routemaster.Drains.Siphon, topic: "burgers", to: MyApp.BurgerSiphon
  drain Routemaster.Drains.Dedup
  drain Routemaster.Drains.IgnoreStale
  drain :a_function_plug, some: "options"
  drain Routemaster.Drains.FetchAndCache
  drain MyApp.MyCustomDrain, some: "other options"
  drain Routemaster.Drains.Notify, listener: MyApp.EventsSink

  def a_function_plug(conn, opts) do
    {:ok, stuff} = MyApp.Utils.do_something(conn.assigns.events, opts[:some])
    Plug.Conn.assign(conn, :stuff, stuff)
  end
end
```

There, `use Routemaster.Drain` sets up all the necessary nuts and bolts of the HTTP endpoint. That, by itself, makes the `MyApp.MyDrainApp` module a valid module plug ready to be mounted in a router. If the library is [configured](#configuration), `MyApp.MyDrainApp` can already receive POST requests from the bus and respond with 204.

The next bit is the asynchronous event processing pipeline. This is where the application gets to do something with the received event payloads. The pipeline is made of a series of processing modules ("drains") defined with the `drain/2` macro. The drains are really just plugs, and the `drain/2` macro behaves just like the [`Plug.Builder.plug/2`](https://hexdocs.pm/plug/Plug.Builder.html#plug/2) macro.

The entire event processing "drain pipeline" runs asynchronously and is independent from the HTTP-specific plug pipeline (which authenticates the request, parses the request body, sets a response, etc). In fact, the drain pipeline is started in the background just before returning a successful 204 HTTP response to the bus.

If the received event batch POST request is invalid for some reason (e.g. invalid auth or invalid JSON), then the drain pipeline is never started.

Once a Drain app has been defined and configured, since it's a Plug, it can be mounted into a host Phoenix application with [`Phoenix.Router.forward/4`](https://hexdocs.pm/phoenix/Phoenix.Router.html#forward/4).

```elixir
defmodule MyApp.Web.Router do
  use MyApp.Web, :router

  scope path: "/events" do
    forward "/", MyApp.MyDrainApp
  end
end
```

The Drain app takes care of its own authentication, and the host application should _not_ wrap it with any extra authentication logic.

### Publish Events

The `Publisher` allows to publish events to the bus server. First, the application must be configured [as shown in the section on the topics](#subscribe-to-topics). Then:

```elixir
Routemaster.Publisher.create("pears", "https://myapp.url/api/pears/42")
Routemaster.Publisher.update("pears", "https://myapp.url/api/pears/42", data: %{mmm: "pears..."})
Routemaster.Publisher.delete("pears", "https://myapp.url/api/pears/42")
Routemaster.Publisher.noop("pears", "https://myapp.url/api/pears/42")
```

All events support an optional `data` payload (must be serializable as JSON) and an optional `timestamp` option (will be set to the current time if missing).

### Fetch Remote Resources

The `Fetcher` HTTP client provides a `get` function to retrieve resources from remote sercvices. Before using it, you must provide authentication credentials for the remote services in your app Mix config file:

```elixir
use Mix.Config

credentials =
  "example.com:username:auth-token,otherapp.url:other-username:other-auth-token"

config :routemaster, service_auth_credentials: credentials
```

Currently they must be provided as a joined string to support configuring apps through the ENV.

Then:

```elixir
Routemaster.Fetcher.get("https://example.com/api/avocados/1337")
Routemaster.Fetcher.get("https://otherapp.url/api/bananas/123", cache: false)
```

The `Fetcher` module integrates automatically with the cache service privided by the library, backed by Redis. If a resource for a given URL is already cached, no HTTP request is executed and the cached value is returned. The cache can be expired manually or automatically when the drain receives new events.

## Installation

The package can be installed by adding `routemaster` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:routemaster, "~> 0.1.0"},
  ]
end
```

Since this library depends on Elixir `1.5`, there is [no need to explicitly declare the application](https://github.com/elixir-lang/elixir/blob/v1.4/CHANGELOG.md#application-inference).

## Dependencies

### Redis

This library includes an entity cache for the JSON resources fetched over the network, backed by [Redis](https://redis.io/). The resources are written to the cache with a configurable TTLs and the keys will expire automatically. It's advisable, however, to configure the redis cache with a [key eviction policy](https://redis.io/topics/lru-cache#eviction-policies). When new data becomes available, the cache entires will automatically be refreshed.

This library requires a second "data" Redis instance. This is used to keep track of the state of the resources and, for example, filter and ignore stale events. This second Redis instance is meant to be independent from the cache, but it _may_ be the same instance. At the moment, expiring keys from the data-Redis is not ideal but will only lead to less effective filters. If you don't plan to use the `IgnoreStale` drain plug, the data-Redis won't be used at all.

## Development Setup

### Install an Elixir Environment

The project targets the latest stable Elixir `1.5` release.

Elixir requires an Erlang runtime, and the correct version of Erlang is installed automatically when installing Elixir.

There are [a number of ways](http://elixir-lang.org/install.html) to install Elixir. If you're on OS X or macOS, the simplest method is to use Homebrew:

```
$ brew update
$ brew install elixir
```

Once installed, verify that these executables are available and work:

```
$ elixir -v
$ mix -v
$ iex -v
```

Also ensure that the build tool `mix` can fetch libraries from the package repositories:

```
$ mix local.hex
$ mix local.rebar
```

### Install Redis

This project depends on Redis. There are a number of ways to install it, for example:
```
$ brew update
$ brew install redis
```

### Setup the Project

Clone the repo, then install the dependencies:

```
$ git clone git@github.com:deliveroo/routemaster-client-ex.git
$ cd routemaster-client-ex
$ mix deps.get
```

The Elixir dependencies and the application source files will be compiled automatically when the application starts, if required (e.g. the first time you run it). You can also compile them manually with:

```
$ mix deps.compile
```

Mix installs dependencies in the project directory, in `./deps/`. This is very similar to what `npm` does. The compiled Elixir bytecode lives in `./_build/`.

### Development Tools

This project is setup with two development tools:

* [Dialyzer](http://erlang.org/doc/man/dialyzer.html) (via [Dialyxir](https://github.com/jeremyjh/dialyxir)) is a static source code and bytecode analysis tool for the Erlang VM. It can be run with `mix dialyzer`. (The first time it will take some time to compile all the stdlib and create its lookup files in `~/.mix`. Successive runs will be fast.)
* [Credo](https://github.com/rrrene/credo) is a static source code analysis tool for Elixir. It's very similar to Ruby's Rubocop. It can be run with `mix credo`.

### Run

Elixir applications are managed with the `mix` executable. Mix is a build tool, a task runner, a package manager and more. It takes care of everything, from compiling to running the server and the tests to linting the code. The other important executable is `iex`, which stands for "interactive Elixir" and starts the REPL.

The `elixir` and `elixirc` executables are also available, but they're considered low-level tools that are not used directly when working with structured applications.

This library is really meant to be used in a host application, where the `Drain` can be plugged into the main application's HTTP interface and where the other modules can be used directly. In development, however, this library can run standalone.

#### Start Redis

Redis is a runtime requirement. In the development and test environment the client will try to connect to the default Redis port on localhost. Just run it with:

```
$ redis-server
```

#### Terminal Commands

In order to work locally, you must duplicate the `bin/_env.example` file as `bin/_env` (gitignored) and use it to set your development configuration. The provided `bin/*` commands will throw an error if this file is missing.

To start a REPL console:

```
$ bin/console
```

This simply runs `iex -S mix`, which is "run the default mix task inside iex". It works a lot like `rails console` or `bin/console` in a Ruby gem. You can also just run `iex` to have the equivalent of `irb` or `pry`.

To start a local **drain server** with attached REPL:

```
$ bin/drain
```

Once it's running, you can send it authenticated requests with:

```bash
curl -i --data '[
    {"type":"update","url":"http://localhost:4242/hedgehogs/2","t":1502651876,"topic":"hedgehogs"},
    {"type":"create","url":"http://localhost:4242/llamas/1","t":1502651912,"data":{"foo":"bar"},"topic":"llamas"},
    {"type":"create","url":"http://localhost:4242/llamas/2","t":1502651913,"topic":"llamas"},
    {"type":"create","url":"http://localhost:4242/rabbits/1","t":1502671234,"topic":"rabbits"}
]' \
    -H "Content-Type: application/json" \
    -H "Authorization: $(bin/build_drain_auth)" \
    http://127.0.0.1:4000/
```

The `bin/build_drain_auth` script will generate a HTTP Basic auth value from the `ROUTEMASTER_DRAIN_TOKEN` var set in your `bin/_env` file.

`mix` and `iex` processes will trap the first `SIGINT` they receive. To terminate them, use `^c` (<kbd>ctrl + c</kbd>) twice.

Unless explicitly set, commands will run in the development environment (`MIX_ENV=dev`).

#### The Dummy Local Service

Starting a `iex` session (so, either `bin/console` or `bin/drain`) will also start _in the same process_ a dummy service listening on http://localhost:4242. This will accept any request and respond with a sort of echo JSON response, and its purpose is to simulate the external services with JSON APIs that this library is supposed to interact with.

In other words, this dummy service is a local target for the `Routemster.Fetcher` module, and sending to the Drain app events with `url` attributes pointing to the dummy service (e.g. in the `curl` command shown above) will ensure that the flow stays local.


## Test

The test suite needs Redis running on localhost. Start it, then run:

```
$ mix espec
```

This will automatically set `MIX_ENV=test`.
