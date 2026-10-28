import Config

strip_wrapping_quotes = fn
  "\"" <> rest ->
    String.trim_trailing(rest, "\"")

  "'" <> rest ->
    String.trim_trailing(rest, "'")

  value ->
    value
end

dotenv_path = Path.expand("../.env", __DIR__)

dotenv_values =
  if File.exists?(dotenv_path) do
    dotenv_path
    |> File.stream!([], :line)
    |> Enum.reduce(%{}, fn line, acc ->
      trimmed = String.trim(line)

      cond do
        trimmed == "" or String.starts_with?(trimmed, "#") ->
          acc

        true ->
          case String.split(String.trim_leading(trimmed, "export "), "=", parts: 2) do
            [key, value] ->
              Map.put(acc, String.trim(key), strip_wrapping_quotes.(String.trim(value)))

            _ ->
              acc
          end
      end
    end)
  else
    %{}
  end

env_value = fn key ->
  case System.get_env(key) || Map.get(dotenv_values, key) do
    value when is_binary(value) ->
      trimmed = String.trim(value)
      if trimmed == "", do: nil, else: trimmed

    _ ->
      nil
  end
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/sokochat start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if env_value.("PHX_SERVER") do
  config :sokochat, SokochatWeb.Endpoint, server: true
end

encryption_key =
  case env_value.("ENCRYPTION_KEY") do
    key when is_binary(key) and byte_size(key) > 0 ->
      key

    _ ->
      if config_env() == :prod do
        raise """
        environment variable ENCRYPTION_KEY is missing.
        Generate one with: mix cloak.gen.key AES.GCM 256
        """
      else
        Base.encode64(:binary.copy(<<0>>, 32))
      end
  end

config :sokochat, Sokochat.Vault,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!(encryption_key)}
  ]

openai_api_key =
  case env_value.("OPENAI_API_KEY") do
    key when is_binary(key) and byte_size(key) > 0 ->
      key

    _ ->
      if config_env() == :prod do
        raise """
        environment variable OPENAI_API_KEY is missing.
        """
      else
        "test-openai-key"
      end
  end

config :sokochat, :openai,
  api_key: openai_api_key,
  model: env_value.("OPENAI_MODEL") || "gpt-5.5",
  reasoning_effort: "low",
  text_verbosity: "low",
  max_output_tokens: 1024

ai_backend =
  if config_env() == :test,
    do: env_value.("TEST_AI_BACKEND") || "openai",
    else: env_value.("AI_BACKEND") || "openai"

unless ai_backend in ["openai", "pi"], do: raise("AI_BACKEND must be openai or pi")

pi_service_token = env_value.("PI_SERVICE_TOKEN")
pi_url = env_value.("PI_URL") || "http://127.0.0.1:4100"
pi_uri = URI.parse(pi_url)

if pi_uri.scheme != "https" and
     not (pi_uri.scheme == "http" and pi_uri.host in ["127.0.0.1", "localhost", "::1"]) do
  raise "PI_URL must use HTTPS outside loopback"
end

if ai_backend == "pi" and (is_nil(pi_service_token) or byte_size(pi_service_token) < 32) do
  raise "PI_SERVICE_TOKEN must contain at least 32 characters when AI_BACKEND=pi"
end

config :sokochat, :intelligence,
  backend: ai_backend,
  pi_url: pi_url,
  pi_token: pi_service_token

# Embeddings power semantic retrieval (RAG) over catalog items. `dimensions`
# must match the `vector(N)` column in the catalog_items migration.
config :sokochat, :embeddings,
  api_key: openai_api_key,
  model: env_value.("OPENAI_EMBEDDING_MODEL") || "text-embedding-3-small",
  dimensions: 1536

# WhatsApp Cloud API. Per-workspace credentials (phone number id, WABA id, access
# token) are configured in the dashboard at /workspaces/:id/meta. Only the Graph
# API version is global. Confirm the current version in your Meta app's dashboard.
config :sokochat, :meta,
  graph_api_version: env_value.("WHATSAPP_GRAPH_API_VERSION") || "v21.0",
  app_secret: env_value.("META_APP_SECRET"),
  require_signature: config_env() == :prod

if config_env() == :prod do
  database_url =
    env_value.("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if env_value.("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :sokochat, Sokochat.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(env_value.("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    env_value.("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = env_value.("PHX_HOST") || "example.com"
  port = String.to_integer(env_value.("PORT") || "4000")

  config :sokochat, :dns_cluster_query, env_value.("DNS_CLUSTER_QUERY")

  config :sokochat, SokochatWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :sokochat, SokochatWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :sokochat, SokochatWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :sokochat, Sokochat.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  if bucket = System.get_env("S3_BUCKET") do
    config :sokochat, Sokochat.Storage,
      adapter: :s3,
      bucket: bucket,
      access_key_id: System.fetch_env!("S3_ACCESS_KEY_ID"),
      secret_access_key: System.fetch_env!("S3_SECRET_ACCESS_KEY"),
      scheme: System.get_env("S3_SCHEME", "http"),
      host: System.fetch_env!("S3_HOST"),
      port: String.to_integer(System.get_env("S3_PORT", "9000")),
      region: System.get_env("S3_REGION", "us-east-1"),
      public_base_url: System.fetch_env!("S3_PUBLIC_BASE_URL")
  end
end
