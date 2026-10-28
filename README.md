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

| Use                     | Email                     | Password      |
| ----------------------- | ------------------------- | ------------- |
| Demo workspace owner    | `demo@sokochat.local`     | `password123` |
| Regular workspace owner | `merchant@sokochat.local` | `password123` |

You can override them with `SEED_USER_EMAIL`, `SEED_USER_PASSWORD`, `SEED_REGULAR_USER_EMAIL`, and `SEED_REGULAR_USER_PASSWORD`.

The seed also creates **Soko Shoes**, owned by `shoes@sokochat.local` with password
`password123` (override with `SEED_SHOES_EMAIL` and `SEED_SHOES_PASSWORD`). Run only
this demo with `mix run priv/repo/seeds_shoes.exs`. It contains Adidas Spezial,
Nike Shox, and Onitsuka Tigers with public R2 images and fictional KES prices,
EU sizes, and stock. Rerunning updates these fixtures without deleting other products.
New images uploaded to R2 must also be added as products in the dashboard or seed.

For live replies, set `OPENAI_API_KEY` in `.env` and restart `mix phx.server`.
The same server-side key powers replies, CTA suggestions, and embeddings; no key
entry is required in the dashboard. In the workspace playground, try “Show me
Adidas Spezial” or “What sizes and prices do you have for Nike Shox?” A specific
product reply can display its image card; broad browsing uses product buttons.
These local catalog IDs are not connected to a Meta Commerce catalog.

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

## Opening a Pull Request

Before opening a pull request:

1. Run `./scripts/check_linters.sh` and fix any formatting, Credo, or test failures.
2. Fill out the pull request summary, changes, and how-to-test sections.
3. Add screenshots or screen recordings for UI changes. Use `N/A` when there are no visual changes.
4. Complete the pull request checklist, including docs, migrations, seeds, and secrets checks when relevant.

### Commit Messages

Use the format `name/what-pr-does` for commit messages.

Examples:

```sh
michael/add-lab-order-filters
sarah/fix-prescription-validation
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Domains](docs/DOMAINS.md)
- [Portals and Routes](docs/PORTALS.md)
- [Authentication](docs/AUTH.md)
- [Data Model](docs/DATA_MODEL.md)
- [Workflows](docs/WORKFLOWS.md)
- [Environment](docs/ENVIRONMENT.md)
