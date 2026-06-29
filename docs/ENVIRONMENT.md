# Environment

Runtime config reads real OS environment variables first, then `.env` values loaded by `config/runtime.exs`.

## Development

Database values from `config/dev.exs`:

| Variable | Default | Required | Purpose |
| --- | --- | --- | --- |
| `DB_USERNAME` | `postgres` | No | PostgreSQL username |
| `DB_PASSWORD` | `postgres` | No | PostgreSQL password |
| `DB_HOST` | `localhost` | No | PostgreSQL host |
| `DB_NAME` | `sokochat_dev` | No | PostgreSQL database |

Runtime values in dev:

| Variable | Default | Required | Purpose |
| --- | --- | --- | --- |
| `PHX_SERVER` | unset | No | Enables endpoint server in releases |
| `ENCRYPTION_KEY` | base64 zero key | No in dev | Cloak AES.GCM key; generate with `mix cloak.gen.key AES.GCM 256` for real data |
| `OPENAI_API_KEY` | `test-openai-key` | No in dev | OpenAI Responses and Embeddings API key |
| `OPENAI_MODEL` | `gpt-5.5` | No | Responses model |
| `OPENAI_EMBEDDING_MODEL` | `text-embedding-3-small` | No | Embedding model; dimensions must match `vector(1536)` |
| `WHATSAPP_GRAPH_API_VERSION` | `v21.0` | No | Meta Graph API version |

Seed-specific values read by `priv/repo/seeds.exs`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SEED_USER_EMAIL` | `demo@sokochat.local` | Demo owner login |
| `SEED_USER_PASSWORD` | `password123` | Demo owner password |
| `SEED_REGULAR_USER_EMAIL` | `merchant@sokochat.local` | Second seeded user login |
| `SEED_REGULAR_USER_PASSWORD` | `password123` | Second seeded user password |
| `SEED_WORKSPACE_NAME` | `Sokopawa Market` | Demo workspace name |
| `WA_WORKSPACE_SLUG` | `sokopawa` | Demo workspace slug and webhook path |
| `WA_PHONE_NUMBER_ID` | unset | Optional seed value for Meta credentials |
| `WA_WABA_ID` | unset | Optional seed value for Meta credentials |
| `WA_ACCESS_TOKEN` | unset | Optional seed value for Meta credentials |

## Test

Values from `config/test.exs`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `MIX_TEST_PARTITION` | unset | Appended to the test database name for partitioned test runs |

Test database defaults to username `postgres`, password `postgres`, host `localhost`, and database `sokochat_test#{MIX_TEST_PARTITION}`. Oban plugins and queues are disabled in tests, and Swoosh uses the test adapter.

## Production

Production-required values from `config/runtime.exs`:

| Variable | Required | Purpose |
| --- | --- | --- |
| `DATABASE_URL` | Yes | Ecto database URL |
| `SECRET_KEY_BASE` | Yes | Phoenix cookie/session signing secret |
| `ENCRYPTION_KEY` | Yes | Base64 AES.GCM key for Cloak encrypted fields |
| `OPENAI_API_KEY` | Yes | OpenAI API key |

Production-optional values:

| Variable | Default | Purpose |
| --- | --- | --- |
| `PHX_SERVER` | unset | Enables the endpoint server in releases |
| `ECTO_IPV6` | unset | Enables IPv6 socket options when `true` or `1` |
| `POOL_SIZE` | `10` | Repo pool size |
| `PHX_HOST` | `example.com` | Public host for endpoint URLs |
| `PORT` | `4000` | HTTP listen port |
| `DNS_CLUSTER_QUERY` | unset | DNSCluster query |
| `OPENAI_MODEL` | `gpt-5.5` | Responses model |
| `OPENAI_EMBEDDING_MODEL` | `text-embedding-3-small` | Embedding model |
| `WHATSAPP_GRAPH_API_VERSION` | `v21.0` | Meta Graph API version |

Per-workspace Meta values (`phone_number_id`, `waba_id`, and `access_token`) are stored through the UI in `meta_connections`; they are not global production env vars.

## Aliases

Aliases in `mix.exs`:

- `mix setup` -> deps, database setup, assets setup, assets build
- `mix ecto.setup` -> create, migrate, run seeds
- `mix ecto.reset` -> drop database, then run `ecto.setup`
- `mix test` -> create and migrate test DB, then run tests
- `mix assets.setup`, `mix assets.build`, `mix assets.deploy`

`mix ecto.reset` is destructive because it drops the configured database. There are no intentionally blocked or overridden destructive aliases.

## Docker

No `Dockerfile`, `docker-compose.yml`, or `compose.yml` is present in the project root.
