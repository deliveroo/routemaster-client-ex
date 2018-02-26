# Changelog

## Unreleased

Fixes:
* Ensure that `Plugs.RootPostOnly` does not accidentally block valid requests (it would happen because [`Phoenix.Router.forward/4`](https://hexdocs.pm/phoenix/Phoenix.Router.html#forward/4) does not strip `conn.request_path` when used in scopes.

## v0.2.0

Enancements:

* Added support to publish events asynchronously with the new `async: true` option for the `Publisher` functions.

Other Changes:

* Documentation fixes.
* Updated dependencies.

## v0.1.0

First public release of the library.
At a high level, from the beginning of the readme:

* `Routemaster.Drain`, a [Plug](https://github.com/elixir-lang/plug) app builder to set up endpoints to receive events over HTTP.
* `Routemaster.Fetcher`, a HATEOAS API client to get entities from other services.
* `Routemaster.Publisher`, a module to publish events to the event bus.
* `Routemaster.Director`, an interface to subscribe to topics, unsubscribe, list and delete (owned) topics, and in general interact with the API of the server.

A fifth private component is `Routemaster.Cache`, used by the `Fetcher` to store retrieved resources and busted by the `Drain` when new data becomes available.
