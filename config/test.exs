import Config
config :windowpane, Oban, testing: :manual

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :windowpane, Windowpane.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "windowpane_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :windowpane, WindowpaneWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "BPRJDjbPrYblf72uip79lIJ+b6spL8z3cqPyO2zpcJHbA91YiSgT3B0vqKgSgmMV",
  server: false

# In test we don't send emails
config :windowpane, Windowpane.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure Mux CORS origins for test environment
config :windowpane, :cors_origin_urls,
  main_app: "http://windowpane.tv:4000",
  studio_app: "http://studio.windowpane.tv:4000"
