defmodule Routemaster.Mixfile do
  use Mix.Project

  @version "0.2.0"

  def version, do: @version

  def project do
    [
      app: :routemaster_client,
      name: "Routemaster Client",
      version: @version,
      elixir: "~> 1.5",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      preferred_cli_env: [espec: :test],
      elixirc_paths: elixirc_paths(Mix.env),
      dialyzer: dialyzer(),
      description: description(),
      package: package(),
      docs: docs(),
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Routemaster.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:redix, "~> 0.6.1"},
      {:plug, "~> 1.4"},
      {:cowboy, "~> 1.1", optional: true},
      {:poison, "~> 3.1"},
      {:tesla, "~> 0.9"},
      {:hackney, "~> 1.9"},
      {:deferred_config, "~> 0.1.1", optional: true},

      {:ex_doc, "~> 0.17", only: :dev},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},

      {:espec, "~> 1.4", only: :test},
      {:bypass, "~> 0.8.0", only: :test},
    ]
  end


  def dialyzer do
    [
      flags: [:error_handling, :race_conditions],
      ignore_warnings: ".dialyzer_ignore",
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "spec/support"]
  defp elixirc_paths(:dev),  do: ["lib", "dev"]
  defp elixirc_paths(_),     do: ["lib"]


  defp description do
    """
    Elixir client for the Routemaster event bus server.

    Supports publishing events, subscribing to topics, receiving and processing events.
    Also incluses a HTTP client integrated with a builtin cache service.
    """
  end


  defp package do
    [
      name: "routemaster_client",
      maintainers: [
        "Tommaso Pavese"
      ],
      licenses: [
        "MIT"
      ],
      links: %{
        "GitHub" => "https://github.com/deliveroo/routemaster-client-ex",
      }
    ]
  end


  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_url: "https://github.com/deliveroo/routemaster-client-ex/",
      source_ref: "v#{@version}"
    ]
  end
end
