# Production readiness evidence

Last reviewed: 2026-10-28. The production-readiness goal is **open**. Source and
startup checks do not establish end-to-end correctness. No tests, live model requests, browser QA, or outbound WhatsApp test messages
were executed by the assistant, following Sean's testing boundary. Sean reported
the regression results below from his own execution.

## Confirmed locally

- The service uses the existing environment key; provider credentials are not
  returned to the browser or committed. Package versions and lockfile are pinned.
- TypeScript static checking (`npm run check`) completed successfully.
- Phoenix source compilation (`mix compile`) completed successfully. Existing
  unrelated application warnings remain; compilation is not a test result.
- PostgreSQL accepted connections to `sokochat_dev`. Read-only SQL confirmed
  `public.ai_turns` and migration `20261028120000` are present.
- The updated Phoenix preview was started on port 4000. Pi was started on 4100
  and reported `ready`, with zero active/queued turns at the readiness check.
- `git diff --check` reported no whitespace errors.
- Final `mix format --check-formatted` passed, and `mix credo --strict` reported
  no issues across 143 source files. These are static checks, not test execution.

These observations are local and dated, not continuous production monitoring.

A human-triggered `hello` completed with a validated greeting: 14,896 ms inside
Pi, one model request and zero tool calls. This confirms provider access for that
turn, not product lookup or restart recovery. GPT-5.5 reasoning has subsequently
changed from `low` to `off` for new admissions to reduce latency. Subsequent live
and regression results are recorded below.

A second human-triggered turn asked for Adidas Spezial sizes and price. Its saved
budget records two model requests and one business tool call. The validated answer
matches catalog item 8 in workspace 4: EU 38 through EU 42, each KES 6,500, with
the correct image URL. PostgreSQL records the completed turn and assistant message
12, whose saved catalog CTA contains that same product and image. This proves
tool-backed product retrieval and card persistence for this case; actual image
rendering in the browser still requires Sean's check. This turn also predates the
reasoning change. It took 17,236 ms within the harness, 19,160 ms through Pi result
publication, and 33 seconds from Postgres admission to completion. The remaining
queue/reconciliation overhead has not been isolated by these timestamps.

After the reasoning change, Sean triggered a fresh greeting and Nike Shox lookup.
The greeting completed in 3,141 ms inside Pi (3,171 ms through result publication),
and six seconds from Postgres admission to completion. The Nike turn completed in
5,602 ms inside Pi (5,625 ms through publication), and eight seconds through
Postgres completion. It used two model requests and one tool call. The response
matches workspace 4 catalog item 9: EU 40 through EU 44, each KES 8,500. Assistant
message 16 saved the matching product/image CTA. Sean also confirmed the image
appears. These are two observed requests, not a latency percentile or load test.

Sean then requested a restart while turn 5 (`message-17`) was pending. The old Pi
process was interrupted with SIGKILL and a new process started against the same
data directory. It reported one active recovered request, then completed that
same ID. PostgreSQL records assistant message 18 and exactly one assistant message
after its user input. The saved Adidas reply and image CTA match catalog item 8.
Its persistent budget records two model requests and one tool call. This verifies
pending-turn recovery across this service interruption; the exact model/tool
checkpoint at interruption was not established. Sean confirmed that exactly one
complete reply and image arrived in the phone preview after the restart.
Phoenix interruption and staging recovery checks remain open.

## Regression results reported by Sean

On 2026-10-28 Sean supplied the complete terminal result for the documented commands:

- Elixir: **15 passed**, ExUnit seed `869314`, no failures reported.
- Node: initially **5 passed, 0 failed**. After the reasoning change Sean reran
  the suite and supplied **7 passed, 0 failed**, no skipped/cancelled tests.

This covers the prepared Pi-client, durable-turn, private-tool callback and webhook
signature tests, plus budget persistence/concurrency, exclusive owner acquisition,
and preservation of tool/reasoning transcripts. Existing compilation warnings did
not fail the run. The result is user-reported evidence, not an assistant test run.
It does not cover live provider behavior, deployed HTTP/TLS, multi-process crash
recovery, container packaging or WhatsApp delivery.

## Implementation and required proof

| Requirement | Implementation | Remaining proof |
| --- | --- | --- |
| Agentic shop lookup | Human-triggered Adidas and Nike lookups returned matching catalog facts and persisted image CTAs; Nike used the new reasoning setting; Sean confirmed image rendering | Broader catalog and failure-path evaluation before production |
| Tenant isolation | Callback checks queued turn, buyer message, conversation and workspace; item queries are workspace-scoped | Positive own-product and negative foreign-product tests; exercise a second workspace |
| Request identity | Immutable snapshot, canonical digest, stable saved-message ID; Meta source-key deduplication | Duplicate requests/webhooks produce one buyer turn and one reply |
| Recovery | Requested Pi interruption recovered message-17 into one saved reply; Sean confirmed one complete reply/image in the preview | Exercise Phoenix interruption and model/tool checkpoint failures in staging |
| Bounded execution | Persisted attempt/tool budgets, expiry, queues and daily tenant quota | Budget/queue/restart regression tests and provider error checks |
| Storage ownership | Linux kernel flock held by the retained file descriptor; same ownership protocol for offline retention | Ownership tests, concurrent-start/crash recovery in staging |
| Channel safety | Transactional assistant persistence, per-part delivery intent/acknowledgment, uncertain-send review | Staging Meta tests across partial sends, timeouts, worker crashes and manual review |
| Webhook authentication | Exact raw-body HMAC verification; production fails closed without Meta app secret | Signed, unsigned and tampered payload tests through deployed HTTP stack |
| Failure recovery | Persisted failure state and a late playground notification; retry remains an explicit new turn | Observe a failure before and after the browser wait timeout |
| Packaging | Non-root Dockerfile, hardened systemd template, operational/retention commands and runbook | Build/review packaging on the target host; validate storage ownership, network/TLS, supervision and restore |

## Test handoff

Run the regression commands in the README's Validation handoff. The documented regression commands passed in Sean's run; live/staging validation
remains open. Include a fresh chat
with greeting, browse, specific product, sizes/prices, image rendering and restart
recovery. Production WhatsApp checks need a configured staging connection and
`META_APP_SECRET`; the OpenAI key alone does not configure Meta.

The Docker image was not built, and the systemd template was not installed or
activated on a VPS. This local setup is not a production deployment. API-backed
workspaces retain their existing context mode; manual catalogs use business tools.
Embeddings/indexing and CTA-rule recommendations retain their existing clients.

For Sean's Coolify-managed VPS, `compose.yaml` and `deploy/COOLIFY.md` now provide
the separate Pi application, persistent volume, runtime variables, proxy/domain
routing, non-root container restrictions, and a stop-then-start update procedure.
`docker compose config --quiet` passed using placeholder credentials. A local
image build was attempted but could not connect to the Docker daemon socket;
no image was built and no containers were started. The `coolify` executable was
not found on this shell's PATH, so no Coolify resources were inspected or changed.

Mark readiness complete only after these proofs exist and any failures are fixed.
