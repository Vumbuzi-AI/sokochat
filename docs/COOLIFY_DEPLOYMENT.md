# SokoChat deployment through Coolify MCP

The target application hostname is `sc.uzskicorp.agency`. Phoenix and Pi are
separate containers with persistent storage, plus a dedicated PostgreSQL database
using `pgvector/pgvector:pg16`. The SokoChat project and private database have been
created on the existing Helsinki server; the database reports healthy. Pi has a
prepared, undeployed Git-backed Compose resource. Phoenix has not been deployed.

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
issues. No tests were run by the assistant. Neither new Docker image has been
built: the local Docker daemon socket is unavailable.

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

## Runtime configuration and DNS

Phoenix needs production `DATABASE_URL`, `SECRET_KEY_BASE`, `ENCRYPTION_KEY`,
`OPENAI_API_KEY`, `PHX_HOST=sc.uzskicorp.agency`, and `AI_BACKEND=pi`. Pi and Phoenix
share a service token. Configure `PI_URL` to the Pi HTTPS origin and
`SOKOCHAT_INTERNAL_URL=https://sc.uzskicorp.agency` on Pi. Keep secrets as runtime
variables, never build arguments. Dedicated production secrets have been generated;
the database password was supplied to its Coolify resource without being printed.

No DNS result was observed for `sc.uzskicorp.agency` at preparation time. Add the
requested hostname to the VPS before TLS issuance. Pi uses
`pi.sc.uzskicorp.agency`, which also needs DNS and a Coolify HTTPS route to container
port 4100. Phoenix listens on container port 4000.

The new database starts empty; local data and demo credentials have not been
copied. WhatsApp remains unconfigured until real workspace Meta credentials and
the production webhook secret are provided. Missing `META_APP_SECRET` leaves
production webhook POSTs closed; it does not prevent the app itself from starting.

See `services/pi-intelligence/PRODUCTION_READINESS.md` for local tests and the
human-confirmed Pi recovery exercise. Deployed provider/tool behavior, user flows,
signed delivery, persistent volume ownership, and backup/restore remain unverified.
