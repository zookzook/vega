use Mix.Config

config :vega, :mongodb,
       url: "mongodb://localhost:27017,localhost:27018,localhost:27019/vega-test?replicaSet=kliniken"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :vega, VegaWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
