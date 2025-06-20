# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :windowpane,
  ecto_repos: [Windowpane.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :windowpane, WindowpaneWeb.Endpoint,
  url: [host: "windowpane.tv", port: 4000],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: WindowpaneWeb.ErrorHTML, json: WindowpaneWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Windowpane.PubSub,
  live_view: [signing_salt: "792J1GSl"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :windowpane, Windowpane.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  windowpane: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  windowpane: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :stripity_stripe, api_key: System.get_env("STRIPE_SECRET")

# Configure Stripe webhook secret
config :windowpane, :stripe_webhook_secret, System.get_env("STRIPE_WEBHOOK_SECRET")

# ExAws configuration with Tigris settings
config :ex_aws,
  access_key_id: System.get_env("TIGRIS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("TIGRIS_SECRET_KEY")

config :ex_aws, :s3,
  scheme: "https://",
  host: "fly.storage.tigris.dev",
  region: "us-east-1",
  port: 443

# Configure Waffle to use Tigris for file uploads
config :waffle,
  storage: Waffle.Storage.S3,
  asset_host: fn bucket, _version -> "https://#{bucket}.fly.storage.tigris.dev" end,
  bucket: System.get_env("TIGRIS_BUCKET")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
