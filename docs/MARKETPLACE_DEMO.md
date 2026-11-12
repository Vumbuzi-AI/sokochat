# Marketplace demo

Design source: [Marketplace · Demo flow](https://doop.design/c/nbdU_ygDzg?page=ftGDDC5Kkz).
The existing Desk v2 components and Sokochat v2 guide remain the visual system.

The configured Sokochat line hosts a platform-owned conversation per buyer.
Public discovery reads active manual products from workspaces enrolled on that
line. Private messages, drafts, credentials and unrelated catalogs are excluded.
Seller-link bindings are a preference in the agent instructions, not a catalog
access boundary. Dedicated numbers and unconfigured shared lines retain their
existing shop-specific behavior.

## Activate

Apply `mix ecto.migrate`. Set `MARKETPLACE_SHARED_LINE_ID` to the **database ID**
of the platform's existing shared line (not Meta's phone number ID), and keep
`AI_BACKEND=pi`. Restart Phoenix after changing environment variables.

Run `mix sokochat.marketplace.setup --enroll-existing` to create the platform
workspace and enroll existing unassigned manual shops. It preserves shops already
attached to a different line. New workspaces enroll transactionally at creation
using a unique seller code. Account registration precedes shop creation; there is
no catalog to enlist until that workspace exists.

The setup command prints an owner-only playground route. It uses the existing
playground UI. Its Request order action explains that requests must be made in
WhatsApp, so browser experimentation cannot send real requests to merchants.

## Buyer and merchant behavior

- A greeting returns a shopping welcome and available categories without a model
  call. Product questions go through Pi and bounded public-catalog tools.
- A seller link starts with that seller. Buyers can ask for another category or
  other merchants in the same conversation. Category selection searches globally.
- Returned product choices resolve to database IDs on the server. A product card
  offers Request order, then Confirm request. Model-supplied order IDs are rejected.
- Confirmation creates an unpaid request for one item. The merchant follows up
  to confirm variants, availability, delivery and payment. Each seller receives a
  separate request under `/workspaces/:id/inbox`, with live updates and a Contacted
  state. The buyer's marketplace transcript is never copied into merchant inboxes.
- Drafts expire after 30 minutes. Changed or unavailable products require a fresh
  request. Repeated deliveries and repeated confirmation of the same draft do not
  create extra orders. Existing durable reply/outbox delivery handles responses.

## Current limits

Manual catalogs only; API-backed inventory is outside this marketplace slice.
Requests contain one product at quantity one. No cart, checkout, payment,
reservation, automatic merchant messaging, scoring, or reply approval mode is
implemented here. No automatic migration of existing buyer chat histories occurs.
Seller preference is agent-guided and needs human evaluation. The shared workspace
inherits Pi's per-workspace queue and daily quota; production capacity needs review.

## Human verification

Tests are authored but have not been run by the assistant. Run:

```sh
mix test test/sokochat/marketplace_test.exs
mix test test/sokochat/meta/shop_router_test.exs test/sokochat/meta/sender_test.exs test/sokochat/conversations/durable_turns_test.exs test/sokochat_web/controllers/intelligence_tool_controller_test.exs
```

Exercise a greeting, multiple merchants' products, seller-link entry followed by
a category change, product selection, order confirmation/repeated confirmation,
merchant-specific visibility, archived/repriced products, and disconnected/retry
behavior. Actual Meta delivery and merchant access must be checked by Sean.

## Local preview fixture

`mix sokochat.marketplace.preview` is restricted to development. It reuses the
Soko Shoes seed and adds a fictional Soko Accessories seller with one sample
iPhone case. It creates a disabled local shared line, never real WhatsApp
credentials. The command prints the marketplace and merchant inbox routes.

The prepared local fixture uses line 1, marketplace workspace 5, Soko Shoes
workspace 4 and Soko Accessories workspace 6. Log in as `shoes@sokochat.local`
for the marketplace preview, or `accessories@sokochat.local` for the accessories
inbox, with the development seed password `password123`. IDs are local only.

Tomorrow's intended demo environment is the existing live Sokochat WhatsApp
number. Local migration/setup does not activate production. Apply the migrations,
configure the actual production shared-line database ID, provision/enroll existing
shops, and restart both Phoenix and Pi as part of an explicitly authorized deploy.

In the packaged release (where Mix tasks are unavailable), run the disabled,
manual-only Coolify task `/app/bin/sokochat eval 'Sokochat.Release.setup_marketplace()'`
after setting `MARKETPLACE_SHARED_LINE_ID` and deploying. This starts no additional
HTTP server or job queues, enrolls unassigned manual shops transactionally, and
prints only workspace IDs and counts. Do not use the local preview fixture in production.
