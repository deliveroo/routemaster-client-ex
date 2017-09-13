# Routemaster Client

[![Build Status](https://travis-ci.com/deliveroo/routemaster-client-ex.svg?token=Jy3hr8CUxbxU6EhNeGRq&branch=master)](https://travis-ci.com/deliveroo/routemaster-client-ex)

This Elixir package is a client for the [Routemaster](https://github.com/deliveroo/routemaster) event bus server application.

The project is a work in progress and it aims to port the functionality of the Ruby clients, [routemaster-drain](https://github.com/deliveroo/routemaster-drain) and [routemaster-client](https://github.com/deliveroo/routemaster-client).

## Content

* [Project Organization](#project-organization)
* [Configuration](#configuration)
* [Development Setup](#development-setup)
    - [Install an Elixir Environment](#install-an-elixir-environment)
    - [Install Redis](#install-redis)
    - [Setup the Project](#setup-the-project)
    - [Development Tools](#development-tools)
    - [Run](#run)
        + [Start Redis](#start-redis)
        + [Terminal Commands](#terminal-commands)
        + [The Dummy Local Service](#the-dummy-local-service)
* [In Production](#in-production)
* [Test](#test)



## Project Organization

The package is organized in four main functional areas:

* `Routemaster.Drain`, a [Plug](https://github.com/elixir-lang/plug) that provides an endpoint to receive events over HTTP.
* `Routemaster.Fetcher`, a HATEOAS API client to get entities from other services.
* `Routemaster.Publisher`, a module to publish events to the event bus.
* `Routemaster.Director`, an interface to subscribe to topics, unsubscribe, list and delete (owned) topics, and in general interact with the API of the server.

The initial milestone is to implement an event receiver close in functionality to the _caching_ Rack app from the Ruby drain, with a cache store that is shared between the `Drain` event receiver and the `Fetcher` API client.

## Configuration

This library is configured with [`Mix.Config`](https://hexdocs.pm/mix/Mix.Config.html#content). It optionally supports Phoenix-style system tuples to dynamically read its configuration from the environment, which means that it can be configured at runtime (on boot) rather than at compile-time.

While using the environment is optional, it's the recommended way to configure a [12-factor application](https://12factor.net/) and it allows to reuse the compiled artifacts with different configurations. When using this library in a project, in order to read the configuration from the env you must declare the optional dependency [`deferred_config`](https://github.com/mrluc/deferred_config) in the project mix file.

You can consult the [`config.exs`](https://github.com/deliveroo/routemaster-client-ex/blob/master/config/config.exs) file for the options that should be set in your application's Mix config, and the [`bin/_env.example`](https://github.com/deliveroo/routemaster-client-ex/blob/master/bin/_env.example) file shows which environment variables are supported.

In order to work locally, you must duplicate the `bin/_env.example` file as `bin/_env` (gitignored) and use it to set your development configuration. The provided `bin/*` commands will throw an error if this file is missing.

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
    {"type":"create","url":"http://localhost:4242/llamas/1","t":1502651912,"data":{"foo":"bar"},"topic":"llamas"}
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

## In Production

**WIP**

You can mount the Drain app into a host Phoenix application with [`Phoenix.Router.forward/4`](https://hexdocs.pm/phoenix/Phoenix.Router.html#forward/4).

```elixir
defmodule MyPhoenixApp.Web.Router do
  use MyPhoenixApp.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope path: "/events" do
    pipe_through :api
    forward "/", Routemaster.Drain.ExampleApp, some: "options"
  end
end
```

The Drain app takes care of its own authentication.

## Test

The test suite needs Redis running on localhost. Start it, then run:

```
$ mix espec
```

This will automatically set `MIX_ENV=test`.
