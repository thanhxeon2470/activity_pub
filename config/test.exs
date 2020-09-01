use Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :activity_pub, ActivityPub.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  database: "activity_pub_test",
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :activity_pub, ActivityPubWeb.Endpoint,
  http: [port: 4002],
  server: false

config :activity_pub, :adapter, ActivityPub.TestAdapter

config :activity_pub, :repo, ActivityPub.Repo

config :activity_pub,
  ecto_repos: [ActivityPub.Repo]

config :activity_pub, Oban,
  repo: ActivityPub.Repo,
  queues: false

config :activity_pub, :instance, federating: false

config :tesla, adapter: Tesla.Mock

# Print only warnings and errors during test
config :logger, level: :warn
