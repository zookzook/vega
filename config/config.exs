# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :vega,
  ecto_repos: [Vega.Repo]

# Configures the endpoint
config :vega, VegaWeb.Endpoint,
  url: [host: "localhost"],
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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
