# Pi Durable on Coolify

Deploy this directory as a separate Git-backed Docker Compose application. Phoenix
can stay in its existing Coolify resource, on this VPS or another VPS. The Pi
service uses the existing OpenAI key at runtime; credentials are never baked into
the image or supplied by the browser.

## Resource configuration

In the intended Coolify project/environment, add the SokoChat Git repository and
choose the Docker Compose build strategy:

| Setting | Value |
| --- | --- |
| Branch | The reviewed branch containing these files |
| Base directory | `/services/pi-intelligence` |
| Docker Compose location | `/compose.yaml` |
| Service | `pi` |
| Container port | `4100` |
| Domain | Your Pi HTTPS domain, with `:4100` in Coolify's domain field |
| Replicas | One |
| Persistent storage | `pi-data` mounted at `/var/lib/sokochat-pi` |

For example, configure `https://pi.example.com:4100` in Coolify. The port suffix
tells its proxy which container port receives traffic. Phoenix connects to
`https://pi.example.com`, using normal HTTPS port 443. Configure DNS to the selected
VPS and let Coolify provision TLS. The Compose file does not publish a host port.
Coolify connects its proxy to the service network.

Git-backed Compose builds need the repository checkout. Do not paste this Compose
definition into an empty service with no source checkout, since `build.context`
expects the Dockerfile and source files beside it.

## Runtime environment

Enter these as runtime variables in the Pi resource's Coolify environment editor:

```dotenv
OPENAI_API_KEY=<existing provider key>
OPENAI_MODEL=gpt-5.5
PI_THINKING_LEVEL=off
PI_SERVICE_TOKEN=<shared random token of at least 32 characters>
SOKOCHAT_INTERNAL_URL=https://chat.example.com
PI_WORKSPACE_DAILY_TURN_LIMIT=1000
```

Use a new production service token shared only by Phoenix and Pi. An operator can
generate one with `openssl rand -hex 32` and save it directly in both resources.
Do not put keys in Git, build arguments, screenshots, or chat.

On the Phoenix resource, configure:

```dotenv
AI_BACKEND=pi
PI_URL=https://pi.example.com
PI_SERVICE_TOKEN=<the same shared token>
```

Retain Phoenix's existing `OPENAI_API_KEY`: background embeddings and CTA-rule
recommendations still use it. Retain its database, encryption/session secrets,
WhatsApp credentials, and `META_APP_SECRET` for signed webhooks. Apply the additive
`20261028120000` database migration through the app's release migration workflow
before switching its backend to Pi. This Compose stack does not deploy Phoenix or
Postgres or migrate its database.

Pi must reach Phoenix at `SOKOCHAT_INTERNAL_URL`, and Phoenix must reach Pi at
`PI_URL`. Both origins require HTTPS outside loopback. `localhost` inside the Pi
container refers to Pi, not Phoenix. The private catalog callback authenticates
using the shared token and saved turn/workspace scope. If a proxy adds access
controls, allow these authenticated service calls through them.

## Storage and updates

The image runs as the non-root `node` user. A fresh Docker named volume inherits
the image directory's ownership. Reused/bind-mounted storage must be writable by
that user; do not delete an existing volume to fix an ownership error. Coolify can
prefix the volume name: check its Persistent Storages page for the actual name.

Keep one service instance on one persistent volume. A replacement container using
the same volume refuses to acquire ownership while the old instance is active.
Use a stop-then-start update, rather than overlapping containers. The 210-second
stop grace period lets active work finish; admitted queued work resumes on startup.
Deploying another resource creates separate storage; it does not migrate existing
Pi checkpoints. Tenant-specific quotas and one active turn per workspace remain
within this service instance.

For maintenance, set Phoenix back to `AI_BACKEND=openai` only if intentional;
already-admitted Pi turns still require reconciliation. Back up Postgres and a
stopped Pi volume together. A named volume survives container replacement but is
not an off-server backup. Do not run `docker compose down --volumes` on live data.

## Deployment handoff

These files prepare the resource. Deployment still requires Sean's explicit
instruction; no VPS resources are created or deployed by adding them.

After Sean deploys, he should check Coolify's build/runtime logs and health state,
then exercise a fresh catalog conversation, image rendering, a restart during a
reply, and signed WhatsApp delivery. Verify volume retention and a backup restore
on the target host. `/health` confirms readiness, not provider access or delivery.
See [the readiness audit](../PRODUCTION_READINESS.md) for existing local evidence.

The Coolify CLI can inspect servers/resources and manage the application through
its saved context. Start with `coolify --help`, `coolify context verify`, and
`coolify resource list`. Exact create/update flags depend on the installed CLI;
inspect its help before changing a resource. API tokens belong in its local
configuration. Resource inspection does not deploy anything.

References: [Coolify Docker Compose applications](https://coolify.io/docs/applications/builds/docker-compose),
[persistent storage](https://coolify.io/docs/services/configuration/persistent-storage),
and [Coolify CLI](https://coolify.io/docs/cli/what-is-the-coolify-cli).
