defmodule Routemaster.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def version, do: @version

  def project do
    [
      app: :routemaster,
      version: @version,
      elixir: "~> 1.4",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      preferred_cli_env: [espec: :test],
      elixirc_paths: elixirc_paths(Mix.env),
      dialyzer: dialyzer(),
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
      {:tesla, "~> 0.7"},
      {:hackney, "~> 1.8"},
      {:deferred_config, "~> 0.1.1", optional: true},

      {:ex_doc, "~> 0.16", only: :dev},
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
end
