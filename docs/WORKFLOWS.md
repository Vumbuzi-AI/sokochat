# Workflows

## New Developer Setup

1. Run `mix setup`.
2. Log in with a seeded account from `README.md`.
3. Open `/workspaces`.
4. Select the seeded Sokopawa workspace or create a new workspace.
5. Use `/workspaces/:id` for the unified setup flow.

Contexts involved: `Sokochat.Accounts`, `Sokochat.Workspaces`, `Sokochat.Catalogs`, `Sokochat.Endpoints`, `Sokochat.CTARules`, `Sokochat.Meta`.

## Workspace Setup

1. The owner creates a workspace through `SokochatWeb.WorkspacesLive.Form`.
2. `Sokochat.Workspaces.create_workspace/2` stores a unique slug for that user.
3. The owner opens `SokochatWeb.WorkspacesLive.Setup`.
4. The business profile step updates workspace fields such as `company_name`, `industry`, `location`, `phone_number`, and `about`.
5. The products step switches `data_source` between `manual` and `api`.
6. The CTA step creates rules used by the assistant.
7. The Meta step stores WhatsApp Cloud API credentials and shows the webhook callback URL.

## Manual Catalog Flow

1. In `/workspaces/:id` or `/workspaces/:id/endpoint`, the owner chooses manual catalog.
2. `Sokochat.Catalogs.upsert_catalog/2` creates the catalog model.
3. `Sokochat.Catalogs.upsert_field/2` adds custom fields.
4. `Sokochat.Catalogs.upsert_item/2` adds or updates catalog items.
5. Saving an item enqueues `Sokochat.Workers.EmbedCatalogItem`.
6. `Sokochat.AI.Retriever.search/3` can use embeddings to fetch relevant active items.
7. `Sokochat.Catalogs.build_workspace_context/3` turns catalog data into assistant context when `data_source` is `manual`.

## JSON Endpoint Flow

1. The owner enters endpoint URL, method, headers, body template, and refresh strategy.
2. `Sokochat.Endpoints.upsert_endpoint/2` stores the endpoint; headers are encrypted.
3. The UI can call `Sokochat.Endpoints.fetch_live_data/1` to test the connection.
4. `Sokochat.Endpoints.refresh_cached_data/1` stores `cached_data` and `last_fetched_at`.
5. Oban runs `Sokochat.Workers.EndpointRefreshWorker` every minute and every five minutes for polling strategies.
6. Conversation dispatch uses live or cached endpoint data when `data_source` is `api`.

## CTA Rules Flow

1. The owner creates CTA rules in `SokochatWeb.WorkspacesLive.CTARules` or the unified setup page.
2. `Sokochat.CTARules` persists each rule with trigger text, type, payload, and priority.
3. `Sokochat.AI.CtaInjector` appends the rules to the system prompt.
4. `Sokochat.Conversations.Dispatcher` asks OpenAI for a short reply plus optional CTA.
5. `SokochatWeb.PlaygroundChat` renders CTA previews in the browser.
6. `Sokochat.Meta.Sender` maps supported CTA payloads to WhatsApp message formats for live conversations.

## Playground Conversation Flow

1. The owner opens `/workspaces/:id/playground` or uses the playground panel inside `/workspaces/:id`.
2. The LiveView creates or loads a playground conversation using `Sokochat.Conversations.get_or_create_conversation/3`.
3. The user submits a message.
4. `Sokochat.Conversations.Dispatcher.dispatch/4` stores the user message, prepares workspace context, calls OpenAI, stores the assistant message, and broadcasts updates.
5. The LiveView receives PubSub messages and streams chat bubbles.
6. `clear_chat` removes the conversation messages for that workspace playground.

## WhatsApp Live Flow

1. The owner saves Meta credentials in `/workspaces/:id/meta`.
2. Meta verifies `GET /webhooks/whatsapp/:slug` using the connection verify token.
3. A buyer sends a WhatsApp message to the connected number.
4. Meta posts to `POST /webhooks/whatsapp/:slug`.
5. `SokochatWeb.WebhookController` extracts inbound text messages and enqueues `Sokochat.Workers.ProcessInboundMessage`.
6. The worker dispatches the message through `Sokochat.Conversations.Dispatcher`.
7. `Sokochat.Meta.Sender.send_reply/4` sends the assistant reply and optional CTA back through the Graph API.
8. Failures update the Meta connection through `Sokochat.Meta.mark_error/2`.
