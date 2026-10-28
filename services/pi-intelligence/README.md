# SokoChat Pi Durable intelligence

This service runs SokoChat's sales assistant with Pi Durable 1.4.0 and the existing
`OPENAI_API_KEY`. Phoenix owns customers, workspace data, conversation history,
policy and delivery. Pi owns model/tool execution, checkpoints and usage.

The implementation is prepared for a single supervised instance on persistent
local storage. Production sign-off requires the regression suite, chat/recovery
checks, and deployment checks below. Sean reported 15 Elixir and 7 Node regression tests passing. Recovery/staging checks
remain open; tests were not executed by the assistant.
There is no claim of production deployment or verified live delivery.
See [the evidence audit](PRODUCTION_READINESS.md) for confirmed checks and open gates.

## Local setup

Linux, Node 24+, and `/usr/bin/flock` (util-linux) are required. From the repository root:

```sh
mix ecto.migrate
npm --prefix services/pi-intelligence ci
npm --prefix services/pi-intelligence start
# In another terminal:
mix phx.server
```

The additive migration was applied to the local development database during setup.
Repository `.env` already has a generated service token and selects Pi. Never
paste the provider key or service token into a browser.

```dotenv
OPENAI_API_KEY=your-existing-key
OPENAI_MODEL=gpt-5.5
AI_BACKEND=pi
PI_URL=http://127.0.0.1:4100
PI_SERVICE_TOKEN=at-least-32-random-characters
SOKOCHAT_INTERNAL_URL=http://127.0.0.1:4000
```

The Node start command loads root `.env`, then optional service `.env`. OS values
win; service-file values override root-file values. Direct `node src/server.ts`
expects environment variables to be injected by the supervisor/container.
Restart both processes after changing shared credentials or origin settings.
Set `AI_BACKEND=openai` and restart Phoenix to restore the direct chat path.
Already-admitted Pi turns still need reconciliation until settled.

Pi defaults to `127.0.0.1:4100`; Phoenix stays on `127.0.0.1:4000`.
`GET /health` reports process readiness and queue sizes without invoking a model.
Readiness does not prove provider access, tool execution or delivery.

GPT-5.5 chat now defaults to Pi `thinkingLevel: off`, which the pinned provider
maps to Responses `reasoning.effort: none`. A human-triggered greeting previously
took 14.9 seconds inside Pi with `low` reasoning, one model request and no tools
or embeddings. The lower setting targets that overhead. Subsequent human-triggered turns
completed in 3.1 seconds inside Pi for a greeting and 5.6 seconds for Nike sizes
and price (six and eight seconds through Postgres completion). The Nike facts
matched the catalog, and Sean confirmed image rendering. These are individual
observations, not a load-test result; broader product evaluation remains open.
Tools and strict output validation remain
enabled. Set `PI_THINKING_LEVEL=low` to restore reasoning if your catalog questions
need it. Other models default to `low`; check their supported levels before
overriding. Model and thinking level are saved at admission, so retries/restarts
keep the original settings. Turns admitted before this change retain `low`.

The seeded shoe-store playground is `/workspaces/4/playground` on this machine:
`shoes@sokochat.local` / `password123`. Try greetings, stock browsing, one shoe,
and a size/price question. All seeded prices, sizes and stock are fictional.

## Flow and files to read

```text
Browser / signed WhatsApp event
  -> Dispatcher: workspace prompt and admission
  -> DurableTurns: Postgres user message + ai_turn + Oban job in one transaction
  -> RunAiTurn: wait for preceding turns, snapshot history, submit same request ID
  -> Node: authenticated admission, disk snapshot, workspace queue and quota
  -> Pi Harness: generation -> business tool(s) -> generation -> strict JSON answer
  -> RunAiTurn: reconcile stored answer into one assistant message
  -> PubSub for the playground; delivery outbox for WhatsApp
```

Start with `src/runtime.ts`, then `src/tools.ts` and `src/server.ts`.
The matching Phoenix files are `conversations/durable_turns.ex`,
`workers/run_ai_turn.ex`, `ai/pi_client.ex`, and
`web/controllers/intelligence_tool_controller.ex` beneath their `lib/sokochat*`
directories. `src/budget.ts` and `src/storage.ts` show persisted execution limits
and atomic file publication. `src/payload.ts` preserves Pi's reasoning/tool-call
history while prepending Phoenix's prior conversation snapshot.

## Agent capabilities and tenant boundary

For manual catalogs the model receives four read-only tools:

- `shop_profile`: factual business profile and contact information.
- `list_categories`: complete category list for this shop.
- `search_products`: bounded, paginated title/category lookup.
- `get_product`: exact active product by ID or external ID, with sizes, price,
  stock metadata and image URL.

The host binds workspace, conversation and saved user-message IDs. These are not
model tool arguments. The private Phoenix callback checks the service token and
joins the user message, conversation, workspace and queued turn before reading
inventory. Product queries always join through that workspace's catalog. No
shell/filesystem tools, arbitrary URL fetches, payments, ordering, reservations,
external messages or other unsupported business actions are offered to the model.

The agent chooses tools for product questions, then produces the existing
`reply` / `cta` / `policy` JSON schema. Product images render through the existing
channel card builder. Tool output is data, not permission to override instructions.
A missing tool/result should produce a truthful recovery reply rather than made-up
prices. Live-data correctness and injection resistance still require evaluation.

Manual Pi chat no longer performs the two message/upsell embedding calls before
its model turn. API-backed workspaces retain their existing JSON context path,
with tool mode `context`; they do not query manual inventory. Background catalog
embeddings and CTA-rule recommendations remain on the existing direct clients.
This is not a migration to OAuth or removal of every provider credential from Phoenix.

## Durable state and limits

Every incoming user message gets `message-<database ID>` as its Pi request ID.
The immutable request snapshot is saved before HTTP 202. Duplicate requests
reacquire it; changed contents under the same ID return 409. Snapshotted model
selection survives later environment changes. Object-key ordering does not change
request identity. WhatsApp retries also reuse a Postgres source key from the Meta
message ID; they do not add another buyer message.

```text
data/
  .owner.lock          # kernel file lock; never delete while in use
  owner.pid            # diagnostic PID only
  <workspace ID>/
    quota-YYYY-MM-DD.json
    message-<message ID>/
      request.json
      budget.json
      session.sqlite    # Pi transcript, tasks, tool intents/results and usage
      session.sqlite-*  # WAL/SHM while open
      result.json       # validated answer + total model tokens + duration, or failure
```

One Pi root is used per turn. Phoenix supplies canonical chat history, so resetting
or clearing chat does not leave a second live history to drift. Deleted conversations
cascade their Postgres turns; subsequent business callbacks fail scope validation.
Pi storage is retained until operational retention removes completed state.

One process owns the data directory, including during offline retention. Do not
mount it across hosts, delete `.owner.lock`, or bypass the owner lock. SQLite recovery protects process
crashes; external provider requests can repeat after a crash before their result
commits. There is no exactly-once billing guarantee or automatic disk replication.

Default limits:

- Four active workspaces, one active turn per workspace.
- 100 active/queued service turns; 25 waiting per workspace.
- 1,000 admitted turns per workspace per UTC day, configurable with
  `PI_WORKSPACE_DAILY_TURN_LIMIT`. This is a turn quota, not a currency budget.
- Eight model attempts and 24 tool calls per turn, reserved on disk before calls.
- 1,024 output tokens per model attempt; GPT-5.5 reasoning off by default
  (`PI_THINKING_LEVEL=low` restores it); 900-character final reply.
- 45 seconds per model request, no SDK retries, one durable generation retry.
- Three minutes of turn execution across restarts; admitted work expires after
  15 minutes including queue time. Phoenix also settles expired queued turns.
- 1 MB submission bodies, 128 KB tool results, 12 products per search page.

These bounds do not replace provider/project spend limits or capacity planning.
Failed results persist. A new user turn is required after a terminal generation
failure. Infrastructure failures retry the original immutable turn via Oban.

## Reply reconciliation and WhatsApp delivery

The browser waits up to 90 seconds for Postgres completion. After that, generation
continues under Oban; the saved assistant message is broadcast when ready. Refreshing
loads saved messages even if a PubSub notification was missed. Completion locks the
turn and commits the assistant message/status together, so repeated result handling
does not append another reply. Turns run in admission order per conversation.
A periodic reconciliation job repairs missing/exhausted job ownership.

WhatsApp messages are delivered by `DeliverAiReply`, one persisted part at a time.
Before calling Meta it records `sending`; after a Meta message ID it advances the
part index. Completed parts are not resent. `sent` means Meta accepted the parts,
not that a recipient read or received them. Transport retries and media fallbacks
are disabled on this outbox path to avoid ambiguous duplicate sends.

A crash or ambiguous HTTP failure after recording `sending` becomes `uncertain`.
It requires operational review; the system cannot determine whether Meta accepted
the request. Inspect state without printing customer text:

```sh
mix sokochat.ai.status
```

After reviewing Meta, explicitly acknowledge the current uncertain part or authorize
its retry. Retrying can duplicate a part that Meta already accepted:

```sh
mix sokochat.ai.resolve_delivery TURN_ID sent --reviewed
mix sokochat.ai.resolve_delivery TURN_ID retry --reviewed
```

The review is recorded on the turn and remaining parts are requeued. No messages
were sent as a setup/test action. The existing real WhatsApp connection must be
configured before live delivery.

Public webhook POSTs verify `X-Hub-Signature-256` against exact raw body bytes when
`META_APP_SECRET` is configured. Production rejects webhook POSTs when the app
secret is missing. GET verification still uses each connection's verify token.
Local development without an app secret permits unsigned fixtures; do not expose
that development server publicly.

## Deployment and operations

For a Coolify-managed VPS, use [`compose.yaml`](compose.yaml) and the
[Coolify setup guide](deploy/COOLIFY.md). The stack builds this Dockerfile, mounts
durable storage, restricts container privileges, and routes through Coolify's
HTTPS proxy. Pi and Phoenix can run on different VPS hosts using authenticated
HTTPS in both directions. One Pi instance owns each data volume.

`deploy/sokochat-pi.service` is a hardened systemd unit template. Provision the
`sokochat-pi` user, install Node at `/usr/bin/node`, deploy source/dependencies to
`/opt/sokochat/services/pi-intelligence`, and put secrets in root-controlled
`/etc/sokochat/pi.env` readable by the service. Review paths before installation.
The unit uses `/var/lib/sokochat-pi`, a private persistent state directory, with
restricted filesystem access and a 210-second graceful stop window. It is supplied
as an artifact, not installed on the VPS or activated by this setup.

A non-root Dockerfile is also provided. It was not built here. Inject secrets at
runtime, mount persistent state with ownership for the image's `node` user, and keep
port 4100 behind private networking or a TLS proxy. Never put secrets in the image.
Set `SOKOCHAT_INTERNAL_URL` to Phoenix's private HTTPS origin when remote. Phoenix's
`PI_URL` and the tool callback origin require HTTPS outside loopback.

Back up Postgres and the Pi data volume. Do not copy an actively written SQLite
file alone while ignoring its WAL. Use a stopped-service snapshot or a proper SQLite
backup strategy. Monitor `/health`, queue age, structured duration/failure logs,
provider spend/rate limits, disk capacity, and uncertain deliveries. Logs contain
IDs and fixed failure types rather than message bodies or credentials.

Retention is an explicit offline operation; pending turns are never pruned. Stop
Pi, then run as the same service account with its configured `PI_DATA_DIR`:

```sh
npm run prune -- --days 30
```

This removes old terminal request snapshots, budgets and SQLite state, retaining a
non-content tombstone. Replays of expired IDs return 410 instead of regenerating.
Restart Pi afterward. Pruning refuses to run while the service owns the directory.
This does not delete Phoenix messages, Postgres turn payloads or external backups;
set their retention according to the product's data policy before deployment.

## Validation handoff

Prepared regression coverage includes tenant scope, unsigned/tampered webhooks,
duplicate inbound admission, idempotent completion, conversation ordering,
ambiguous delivery, preserved tool-call transcripts, persisted budgets and exclusive
storage ownership. Run these yourself under the agreed testing boundary:

```sh
mix test test/sokochat/ai/pi_client_test.exs test/sokochat/conversations/durable_turns_test.exs test/sokochat_web/controllers/intelligence_tool_controller_test.exs test/sokochat_web/verify_meta_signature_test.exs
npm --prefix services/pi-intelligence test
```

Also exercise a fresh playground chat, factual tool lookup and images, another
workspace, reconnect/timeout recovery, clearing a conversation during generation,
provider errors/limits, service restarts during a model/tool call, and signed Meta
webhooks/delivery in a staging setup. Check the deployed supervisor, TLS/private
routing, credentials, disk permissions and backup/restore procedure. Static checking
or process readiness is not evidence that these runtime behaviors passed.

Upstream Pi API is experimental. Package versions and the lockfile are pinned;
review changes and rerun this validation before upgrades.
