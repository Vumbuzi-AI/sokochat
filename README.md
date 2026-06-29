# Sokochat

Sokochat is a Phoenix LiveView application for building AI-powered WhatsApp sales assistants. A workspace owner signs in, creates a business workspace, connects either a manual product catalog or a JSON API, defines CTA rules, tests replies in a browser playground, and then connects Meta WhatsApp Cloud API credentials.

Major areas:

- Public marketing home page at `/`
- Email/password account registration, login, confirmation, reset, and settings
- Authenticated workspace setup and management under `/workspaces`
- Product data ingestion through manual catalogs or JSON endpoints
- CTA rule configuration and AI-assisted CTA recommendations
- Browser playground for WhatsApp-style testing
- Meta webhook verification and inbound WhatsApp processing
- Development dashboard and mailbox under `/dev` when `dev_routes` is enabled

## Prerequisites

- Elixir `~> 1.14` as declared in `mix.exs`
- Erlang/OTP compatible with your installed Elixir version
- PostgreSQL with the `citext` and `vector` extensions available
- No `.tool-versions`, Dockerfile, or `docker-compose.yml` is committed
- Node is not required by a `package.json`; assets use Phoenix-managed esbuild and Tailwind binaries

## Setup

```sh
mix setup
```

That command gets dependencies, creates and migrates the database, runs `priv/repo/seeds.exs`, installs esbuild/Tailwind if missing, and builds assets.

Development database defaults from `config/dev.exs`:

- username: `postgres`
- password: `postgres`
- host: `localhost`
- database: `sokochat_dev`

Override those with `DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, and `DB_NAME` if needed.

## Run

```sh
mix phx.server
```

Open http://localhost:4000.

## Seeded Logins

The seed script creates confirmed users and resets these seed account passwords each time it runs.

| Use | Email | Password |
| --- | --- | --- |
| Demo workspace owner | `demo@sokochat.local` | `password123` |
| Regular workspace owner | `merchant@sokochat.local` | `password123` |

You can override them with `SEED_USER_EMAIL`, `SEED_USER_PASSWORD`, `SEED_REGULAR_USER_EMAIL`, and `SEED_REGULAR_USER_PASSWORD`.

## Common Commands

```sh
mix test
mix format
mix credo
mix ecto.setup
mix ecto.reset
mix run priv/repo/seeds.exs
mix assets.build
mix assets.deploy
```

`mix credo` runs static analysis using `.credo.exs`. `mix ecto.reset` is destructive because it drops and recreates the database. There are no intentionally blocked aliases in `mix.exs`.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Domains](docs/DOMAINS.md)
- [Portals and Routes](docs/PORTALS.md)
- [Authentication](docs/AUTH.md)
- [Data Model](docs/DATA_MODEL.md)
- [Workflows](docs/WORKFLOWS.md)
- [Environment](docs/ENVIRONMENT.md)
