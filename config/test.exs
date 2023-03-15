import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lv_new_app, LvNewAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gjr5qk5Gqh1XrBk4ylSDihK1ezvJkcVLyURHXldPXHnj0H5RJUWLE5tqGqmkhsKR",
  server: false

# In test we don't send emails.
config :lv_new_app, LvNewApp.Mailer,
  adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
