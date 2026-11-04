# SokoChat deployment through Coolify MCP

The target application hostname is `sc.uzskicorp.agency`. Phoenix and Pi are
separate containers with persistent storage, plus a dedicated PostgreSQL database
using `pgvector/pgvector:pg16`. The SokoChat project and private database have been
created on the existing Helsinki server. Phoenix, Pi, and PostgreSQL all report
`running:healthy`. Both Docker deployments finished through MCP at commit
`35de1d0`. SokoChat responds with HTTP 200 over verified HTTPS; Pi's HTTPS
`/health` reports `ready` with zero active/queued turns at the readiness check.

## Build artifacts

`Dockerfile.coolify` builds Phoenix with the repository's Elixir 1.20.2 / OTP 29.0.2
toolchain and packages an OTP release into a non-root Debian runtime. It compiles
assets without including local dependencies, environment files, session data, or
uploaded product images in the build context. Its server entrypoint runs additive
migrations before starting Phoenix and stops if migration fails. It does not run
seeds, create demo passwords, or reset the database.

Mount Phoenix product uploads at `/var/lib/sokochat/uploads`. The packaged static
uploads path links to that volume so uploaded images survive container updates.
Pi's image and Compose definition live in `services/pi-intelligence`; its state
volume is mounted at `/var/lib/sokochat-pi`.

The release entrypoint compiled, formatting passed, and strict Credo reported no
issues. No tests were run by the assistant. Local image building is unavailable
because the Docker daemon socket is absent. Both images were built successfully
on Coolify. The initial Phoenix attempt started and migrated successfully but its
health check needed `curl`; the runtime image now includes it. Pi's first attempt
failed on required Compose interpolation during the build; empty build-time values
are now permitted while the actual service still requires runtime credentials.

## Source versus deployment control

Coolify MCP creates resources, configures environment/storage, and triggers
deployment. The inspected Akiwah staging resource points at a Git Dockerfile, but
that Dockerfile only pulls `ghcr.io/uzski-corp/aki-wah:staging`; its comment states
that GitHub Actions publishes the image.

There are two supported paths for SokoChat:

- Build Dockerfiles from Git source on Coolify and trigger deployment through MCP,
  without using GitHub Actions for the deployment.
- Build and publish versioned Phoenix and Pi images elsewhere, configure Coolify
  Docker-image resources, and trigger deployment through MCP. This removes Git
  from the deployment path. It needs a working image builder and registry access.

Sean selected Git source with deployment triggered through Coolify MCP. The
Phoenix release Dockerfile is built from the repository checkout on Coolify;
GitHub Actions is not the deployment controller. Pi uses its own Git-backed
Compose resource. The source branch is `sean/soko-chat-engine`.
Git push auto-deploy is disabled on both resources, so publishing source does not
itself start a deployment. The deployed source selection is commit `35de1d0`.

## Runtime configuration and DNS

Phoenix needs production `DATABASE_URL`, `SECRET_KEY_BASE`, `ENCRYPTION_KEY`,
`OPENAI_API_KEY`, `PHX_HOST=sc.uzskicorp.agency`, and `AI_BACKEND=pi`. Pi and Phoenix
share a service token. Configure `PI_URL` to the Pi HTTPS origin and
`SOKOCHAT_INTERNAL_URL=https://sc.uzskicorp.agency` on Pi. Keep secrets as runtime
variables, never build arguments. Dedicated production secrets have been generated;
the database password was supplied to its Coolify resource without being printed.
Production variables have been saved as runtime-only values on both app resources.

SokoChat uses `https://sc.uzskicorp.agency` through Cloudflare. Pi uses
`https://pi.sc.uzskicorp.agency` with DNS-only records pointing at the VPS, and
Coolify supplies its TLS certificate. Keep Pi DNS-only: standard Cloudflare
Universal SSL does not cover this nested hostname. Pi listens on container port
4100, and Phoenix listens on container port 4000. Both HTTPS origins were checked
without disabling certificate verification.

## Backup state

The private database has a daily backup at 00:00 UTC (03:00 Africa/Nairobi), with
seven local copies/days of retention. The first execution succeeded and produced
a 54,191-byte dump. There is no configured S3 backup destination. These are local
database backups, not off-server disaster recovery; restore, Pi checkpoints and
product-upload backup procedures remain to be validated.

The new database starts empty; local data and demo credentials have not been
copied. WhatsApp remains unconfigured until real workspace Meta credentials and
the production webhook secret are provided. Missing `META_APP_SECRET` leaves
production webhook POSTs closed; it does not prevent the app itself from starting.

See `services/pi-intelligence/PRODUCTION_READINESS.md` for local tests and the
human-confirmed Pi recovery exercise. Deployed provider/tool behavior, user flows,
signed delivery, volume retention through container replacement, and backup restore
remain unverified. Local demo accounts/catalogs were not copied to the public app.
