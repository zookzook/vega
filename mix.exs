defmodule Vega.MixProject do
  use Mix.Project

  def project do
    [
      app: :vega,
      version: "0.1.0",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Vega.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.5.1"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.2"},
      {:mongodb_driver, "~> 0.7"},
      #{:yildun, "~> 0.1.0"},
      {:yildun, path: "/Users/micha/projects/elixir/yildun"},
      {:phoenix_live_view, "~> 0.12.1"},
      {:timex, "~> 3.6.1"},
      {:ex_cldr, "~> 2.13"},
      {:ex_cldr_dates_times, "~> 2.3"},
      {:ex_cldr_collation, "~> 0.2.0"},
      {:oauth2, "~> 2.0"},
      {:libcluster, "~> 3.2"},
      {:earmark, "~> 1.4"},
      {:cachex, "~> 3.2"},
      {:floki, ">= 0.0.0", only: :test}
    ]
  end

end
