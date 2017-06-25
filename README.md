# Routemaster Client

[![Build Status](https://travis-ci.com/deliveroo/routemaster-client-ex.svg?token=Jy3hr8CUxbxU6EhNeGRq&branch=master)](https://travis-ci.com/deliveroo/routemaster-client-ex)

This Elixir package is a client for the [Routemaster](https://github.com/deliveroo/routemaster) event bus server application.

The project is a work in progress and it aims to port the functionality of the Ruby clients, [routemaster-drain](https://github.com/deliveroo/routemaster-drain) and [routemaster-client](https://github.com/deliveroo/routemaster-client).


## Project organization

The package is organized in three main functional areas:

* `Routemaster.Drain`, a [Plug](https://github.com/elixir-lang/plug) that provides an endpoint to receive events over HTTP.
* `Routemaster.Fetcher`, a HATEOAS API client to get entities from other services.
* `Routemaster.Publisher`, a module to publish events to the event bus.

The initial milestone is to implement an event receiver close in functionality to the _caching_ Rack app from the Ruby drain, with a cache store that is shared between the the event receiver and the `Fetcher` API client.

## Development Setup

### Install an Elixir environment

The project targets the latest stable Elixir `1.4.x` release.

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

### Setup the project

Clone the repo, then install the dependencies:

```
$ git clone git@github.com:deliveroo/routemaster-client-ex.git
$ cd routemaster-client-ex
$ mix deps.get
```

The Elixir dependencies and the application source files will be compiled automatically when the application starts, if required (e.g. the first time you run it). You can do it explicitly with:

```
$ mix deps.compile
```

Mix installs dependencies in the project directory, in `./deps/`. This is very similar to what `npm` does. The compiled Elixir bytecode lives in `./_build/`.

## Run

Elixir applications are managed with the `mix` executable. Mix is a build tool, a task runner, a package manager and more. It takes care of everything, from compiling to running the server and the tests to linting the code. The other important executable is `iex`, which stands for "interactive Elixir" and starts the REPL.

The `elixir` and `elixirc` executables are also available, but they're considered low-level tools that are not used directly when working with structured applications.

### Start Redis

Redis is a runtime requirement. In the development and test environment the client will try to connect to the default Redis port on localhost. Just run it with:

```
$ redis-server
```

### Terminal commands

To start a REPL console:

```
$ iex -S mix
```

This works a lot like `rails console` or `bin/console` in a Ruby gem. You can also just run `iex` to have the equivalent of `irb` or `pry`.

`mix` and `iex` processes will trap the first `SIGINT` they receive. To terminate them, use `^c` (<kbd>ctrl + c</kbd>) twice.

Unless explicitly set, commands will run in the development environment (`MIX_ENV=dev`).

## Test

The test suite needs Redis running on localhost. Start it, then run:

```
$ mix espec
```

This will automatically set `MIX_ENV=test`.
