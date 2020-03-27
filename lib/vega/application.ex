defmodule Vega.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do

    # List all child processes to be supervised
    children = [
      # Start the endpoint when the application starts
      {Mongo, [name: :mongo, url: Application.get_env(:vega, :mongodb)[:url], timeout: 60_000, pool_size: 10, idle_interval: 10_000]},
      VegaWeb.Endpoint,
      # Starts a worker by calling: Vega.Worker.start_link(arg)
      # {Vega.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Vega.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    VegaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
