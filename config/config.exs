# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :vega,
  ecto_repos: [Vega.Repo]

config :vega, VegaWeb.Gettext,
       default_locale: "de", locales: ~w(en de)

config :vega, :mongodb,
   url: "mongodb://localhost:27017,localhost:27018,localhost:27019/vega?replicaSet=kliniken"

# Configures the endpoint
config :vega, VegaWeb.Endpoint,
  url: [host: "lvh.me"],
  secret_key_base: "mDuucO+oaLXjtnaTHVS3HXA/um73iGvJDWanDp86Poht3raBddI4GaKQV3kRqvi5",
  render_errors: [view: VegaWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Vega.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "jyw8j1pk"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :libcluster,
       topologies: [
         vega: [
           # The selected clustering strategy. Required.
           strategy: Cluster.Strategy.Epmd,
           # Configuration for the provided strategy. Optional.
           #config: [hosts: [:"a@127.0.0.1"]],
           config: [hosts: [:"a@127.0.0.1", :"b@127.0.0.1"]],
           # The function to use for connecting nodes. The node
           # name will be appended to the argument list. Optional
           connect: {:net_kernel, :connect_node, []},
           # The function to use for disconnecting nodes. The node
           # name will be appended to the argument list. Optional
           disconnect: {:erlang, :disconnect_node, []},
           # The function to use for listing nodes.
           # This function must return a list of node names. Optional
           list_nodes: {:erlang, :nodes, [:connected]},
         ]
       ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
