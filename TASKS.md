# WhatsappBot — Task Checklist for Claude Code

> Work through these tasks in order. Each task is self-contained with enough
> context for Claude Code to execute it without re-reading the whole project.
> Use Markdown checkboxes as you go, and run `mix test` after every task group.

---

## TASK GROUP 1 — Project bootstrap

- [x] `T1.1` Verify Phoenix app exists
  - [x] Check that `mix.exs` exists and the app is named `:whatsappbot`.
  - [x] Confirm Phoenix 1.7+, LiveView, Ecto, and Tailwind are present.
  - [x] If not, run `mix phx.new whatsappbot --live --database postgres`.

- [x] `T1.2` Add dependencies to `mix.exs`
  - [x] Add the following to `deps`:
    ```elixir
    {:req, "~> 0.5"},                  # HTTP client for endpoint connector + Meta API
    {:oban, "~> 2.17"},                # Background job processing
    {:cloak_ecto, "~> 1.3"},           # Field-level encryption
    {:jason, "~> 1.4"},                # JSON (likely already present)
    {:plug_cowboy, "~> 2.7"},          # (likely already present)
    {:ex_rated, "~> 2.1"},             # Rate limiting for webhook
    {:floki, "~> 0.36", only: :test},  # HTML parsing in tests
    ```
  - [x] Run `mix deps.get`.

- [x] `T1.3` Configure database
  - [x] Edit `config/dev.exs` and set the correct Postgres credentials.
  - [x] Create the database with `mix ecto.create`.

- [x] `T1.4` Configure Oban
  - [x] Add this to `config/config.exs`:
    ```elixir
    config :whatsappbot, Oban,
      repo: Whatsappbot.Repo,
      plugins: [Oban.Plugins.Pruner],
      queues: [default: 10, endpoint_refresh: 5, meta_send: 10]
    ```
  - [x] Add `{Oban, Application.fetch_env!(:whatsappbot, Oban)}` to the supervision tree in `application.ex`.

- [x] `T1.5` Set up Cloak encryption
  - [x] Generate a secret key with `mix cloak.gen.key AES.GCM 256`.
  - [x] Add this to `config/runtime.exs`:
    ```elixir
    config :whatsappbot, Whatsappbot.Vault,
      ciphers: [
        default: {Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1",
          key: Base.decode64!(System.fetch_env!("ENCRYPTION_KEY"))}
      ]
    ```
  - [x] Create `lib/whatsappbot/vault.ex`:
    ```elixir
    defmodule Whatsappbot.Vault do
      use Cloak.Vault, otp_app: :whatsappbot
    end
    ```
  - [x] Add the Vault to the supervision tree.

---

## TASK GROUP 2 — Authentication

- [ ] `T2.1` Generate `phx.gen.auth`
  - [ ] Run `mix phx.gen.auth Accounts User users`.
  - [ ] Run `mix ecto.migrate`.
  - [ ] Confirm the generator created the User schema, registration/login/logout LiveViews, and session tokens.

- [ ] `T2.2` Customise the registration form
  - [ ] Add a required `name` field to the registration form in `lib/whatsappbot_web/live/user_registration_live.ex`.
  - [ ] Add `name` to the User schema and migration with `add_column :users, :name, :string`.
  - [ ] Show the user's name in the top nav after login.

- [ ] `T2.3` Add a post-registration redirect
  - [ ] After successful registration, redirect to `/workspaces/new` instead of `/`.

- [ ] `T2.4` Write auth tests
  - [ ] Test: register with valid data redirects to `/workspaces/new`.
  - [ ] Test: register with duplicate email shows an error.
  - [ ] Test: login establishes a session.
  - [ ] Test: logout clears the session.

---

## TASK GROUP 3 — Workspaces

- [ ] `T3.1` Generate Workspace schema
  - [ ] Run:
    ```bash
    mix phx.gen.schema Workspaces.Workspace workspaces \
      account_id:references:users \
      name:string \
      slug:string \
      ai_instructions:text \
      language:string
    mix ecto.migrate
    ```

- [ ] `T3.2` Create workspace context in `lib/whatsappbot/workspaces.ex`
  - [ ] Add `list_workspaces(user_id)` scoped to account.
  - [ ] Add `get_workspace!(id, user_id)` that raises if not found or wrong owner.
  - [ ] Add `create_workspace(attrs, user_id)`.
  - [ ] Add `update_workspace(workspace, attrs)`.
  - [ ] Add `delete_workspace(workspace)`.
  - [ ] Auto-generate a slug from name on create using downcase and spaces-to-hyphens.

- [ ] `T3.3` Build Workspaces LiveView (index + form)
  - [ ] Add routes:
    - [ ] `GET /workspaces` lists all workspaces for the logged-in user.
    - [ ] `GET /workspaces/new` shows the create form.
    - [ ] `GET /workspaces/:id/edit` shows the edit form.
  - [ ] `WorkspacesLive.Index` renders a card grid of workspaces.
  - [ ] Each card shows name, slug, language badge, and an "Open" button.
  - [ ] Add a "New workspace" button in the top right.
  - [ ] `WorkspacesLive.Form` includes:
    - [ ] Name (required).
    - [ ] AI Instructions textarea with placeholder `"You are a helpful sales assistant for..."`.
    - [ ] Language selector: English only | Swahili only | Both.
  - [ ] On save, redirect to `/workspaces/:id`.

- [ ] `T3.4` Build workspace dashboard LiveView
  - [ ] Add route `GET /workspaces/:id`.
  - [ ] Show 4 cards linking to:
    - [ ] Data Endpoint → `/workspaces/:id/endpoint`
    - [ ] CTA Rules → `/workspaces/:id/cta_rules`
    - [ ] Playground → `/workspaces/:id/playground`
    - [ ] Meta Connection → `/workspaces/:id/meta`
  - [ ] Show green status badges for configured sections and grey for unconfigured ones.

- [ ] `T3.5` Write workspace tests
  - [ ] Test: create workspace auto-generates slug.
  - [ ] Test: another user's workspace cannot be accessed.
  - [ ] Test: workspace AI instructions can be updated.

---

## TASK GROUP 4 — Data endpoint connector

- [ ] `T4.1` Generate Endpoint schema
  - [ ] Run:
    ```bash
    mix phx.gen.schema Endpoints.Endpoint endpoints \
      workspace_id:references:workspaces \
      url:string \
      method:string \
      headers_encrypted:binary \
      body_template:text \
      refresh_strategy:string \
      last_fetched_at:utc_datetime \
      cached_data:map
    mix ecto.migrate
    ```

- [ ] `T4.2` Add Cloak encrypted field for headers
  - [ ] Replace `headers_encrypted` in the Endpoint schema with:
    ```elixir
    field :headers, Whatsappbot.Encrypted.Map
    ```
  - [ ] Create `lib/whatsappbot/encrypted/map.ex` using `Cloak.Ecto.Binary` behaviour.

- [ ] `T4.3` Create endpoint context in `lib/whatsappbot/endpoints.ex`
  - [ ] Add `get_endpoint(workspace_id)` for one endpoint per workspace in v1.
  - [ ] Add `upsert_endpoint(workspace_id, attrs)`.
  - [ ] Add `fetch_live_data(endpoint)` returning `{:ok, data}` or `{:error, reason}`.
  - [ ] Add `refresh_cached_data(endpoint)` updating `cached_data` and `last_fetched_at`.
  - [ ] Implement `fetch_live_data` logic:
    - [ ] If method is `"GET"`, call `Req.get!(url, headers: headers)`.
    - [ ] If method is `"POST"`, substitute `{{query}}` in `body_template` and call `Req.post!(url, json: body, headers: headers)`.
    - [ ] Parse the response body as JSON.
    - [ ] Return at most the first 50 items to avoid token bloat.

- [ ] `T4.4` Build Endpoint LiveView at `/workspaces/:id/endpoint`
  - [ ] Add form fields:
    - [ ] URL (required text input).
    - [ ] Method (GET / POST select).
    - [ ] Headers textarea using `Key: Value` per line.
    - [ ] Body template textarea shown only for POST, with a hint to use `{{query}}`.
    - [ ] Refresh strategy select: On demand | Every 60s | Every 5 min.
  - [ ] Add a "Test connection" button.
  - [ ] On click, call `fetch_live_data` and show a collapsible JSON preview.
  - [ ] Show a red banner with HTTP status or error message on failure.
  - [ ] Show "Last fetched: X minutes ago" when cached data exists.

- [ ] `T4.5` Add Oban worker for polling endpoints
  - [ ] Create `lib/whatsappbot/workers/endpoint_refresh_worker.ex`.
  - [ ] Schedule it with recurring Oban cron for `poll_60s` and `poll_300s`.
  - [ ] Call `Endpoints.refresh_cached_data(endpoint)`.
  - [ ] Broadcast `{:endpoint_refreshed, workspace_id}` via PubSub so Playground can react.

- [ ] `T4.6` Write endpoint tests
  - [ ] Test: GET endpoint returns parsed JSON.
  - [ ] Test: POST endpoint substitutes `{{query}}`.
  - [ ] Test: headers are encrypted at rest.
  - [ ] Test: `fetch_live_data` returns `{:error, _}` on bad URL.

---

## TASK GROUP 5 — AI layer

- [ ] `T5.1` Configure Anthropic API
  - [ ] Add this to `config/runtime.exs`:
    ```elixir
    config :whatsappbot, :anthropic,
      api_key: System.fetch_env!("ANTHROPIC_API_KEY"),
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024
    ```

- [ ] `T5.2` Build AI context builder in `lib/whatsappbot/ai/context_builder.ex`
  - [ ] Implement `build_system_prompt(workspace, endpoint_data)`.
  - [ ] Use this template:
    ```text
    You are an AI sales assistant for {{workspace.name}}.

    INSTRUCTIONS:
    {{workspace.ai_instructions}}

    LANGUAGE: {{language_instruction}}

    CURRENT DATA FROM THE BUSINESS:
    {{endpoint_data_as_formatted_text}}

    RULES:
    - Answer only from the data provided. If you don't know, say so.
    - Be concise. WhatsApp messages should be short.
    - Never make up prices, stock levels, or contact details.
    - At the end of your JSON response, include a "cta" key if a CTA rule applies.
      Otherwise set "cta" to null.

    RESPONSE FORMAT (always valid JSON):
    {
      "reply": "your message text here",
      "cta": null | { "type": "website|phone|whatsapp|reply_buttons|list_message", "payload": {...} }
    }
    ```
  - [ ] Language instruction mapping:
    - [ ] `"en"` → `"Respond in English only."`
    - [ ] `"sw"` → `"Respond in Swahili only."`
    - [ ] `"both"` → `"Detect the buyer's language and respond in the same language (English or Swahili)."`
  - [ ] Format endpoint JSON into a readable text block.
  - [ ] Truncate endpoint data to 3000 characters max.

- [ ] `T5.3` Build CTA rules injector in `lib/whatsappbot/ai/cta_injector.ex`
  - [ ] Implement `inject_cta_rules(system_prompt, cta_rules)`.
  - [ ] Append this section to the system prompt:
    ```text
    CTA RULES (apply the first matching rule):
    1. {{rule.trigger_description}} → use CTA type "{{rule.cta_type}}" with payload {{rule.cta_payload_as_json}}
    2. ...
    ```

- [ ] `T5.4` Build Claude client in `lib/whatsappbot/ai/claude_client.ex`
  - [ ] Implement `chat(messages, system_prompt)`.
  - [ ] Return `{:ok, %{reply: text, cta: map_or_nil, tokens: integer}}` or `{:error, reason}`.
  - [ ] POST to `https://api.anthropic.com/v1/messages`.
  - [ ] Send headers `x-api-key`, `anthropic-version: 2023-06-01`, and `content-type: application/json`.
  - [ ] Parse `response.content[0].text` as JSON.
  - [ ] If JSON parsing fails, treat raw text as the reply with `cta: nil`.
  - [ ] Log total tokens from `usage.input_tokens + usage.output_tokens`.

- [ ] `T5.5` Build conversation context builder
  - [ ] Implement `build_messages(conversation_id, new_user_message)`.
  - [ ] Load the last 10 messages from the DB.
  - [ ] Append the new user message.
  - [ ] Return messages in Anthropic format `%{role:, content:}`.

- [ ] `T5.6` Write AI layer tests
  - [ ] Test: context builder injects data into a valid prompt.
  - [ ] Test: CTA rules injector appends rules correctly.
  - [ ] Test: Claude client parses a valid JSON reply.
  - [ ] Test: Claude client handles malformed JSON gracefully.
  - [ ] Use `Req.Test` stubs and avoid real API calls.

---

## TASK GROUP 6 — Conversations and messages

- [ ] `T6.1` Generate schemas
  - [ ] Run:
    ```bash
    mix phx.gen.schema Conversations.Conversation conversations \
      workspace_id:references:workspaces \
      phone_number:string \
      source:string
    mix ecto.migrate

    mix phx.gen.schema Conversations.Message messages \
      conversation_id:references:conversations \
      role:string \
      content:text \
      cta:map \
      endpoint_snapshot:map \
      tokens_used:integer
    mix ecto.migrate
    ```

- [ ] `T6.2` Build conversations context in `lib/whatsappbot/conversations.ex`
  - [ ] Add `get_or_create_conversation(workspace_id, phone_number, source)`.
  - [ ] Add `list_conversations(workspace_id)` ordered by latest message.
  - [ ] Add `get_conversation!(id, workspace_id)`.
  - [ ] Add `add_message(conversation, role, content, opts \\ [])`.
  - [ ] Support opts for `cta`, `endpoint_snapshot`, and `tokens_used`.
  - [ ] Add `list_messages(conversation_id)` returning the last 50 messages ordered ascending.

- [ ] `T6.3` Build message dispatcher in `lib/whatsappbot/conversations/dispatcher.ex`
  - [ ] Implement `dispatch(workspace_id, phone_number, user_message, source \\ :playground)`.
  - [ ] Steps:
    - [ ] Load workspace, endpoint, and `cta_rules`.
    - [ ] Call `get_or_create_conversation(workspace_id, phone_number, source)`.
    - [ ] Fetch endpoint data, using cache unless refresh is on-demand.
    - [ ] Save the user message with `endpoint_snapshot`.
    - [ ] Build the system prompt and inject CTA rules.
    - [ ] Build Anthropic messages.
    - [ ] Call `claude_client.chat(messages, system_prompt)`.
    - [ ] Save the assistant reply with `cta` and `tokens_used`.
    - [ ] Broadcast `{:new_message, message}` via PubSub on `"conversation:#{conversation.id}"`.
    - [ ] Return `{:ok, message}`.

---

## TASK GROUP 7 — CTA rules

- [ ] `T7.1` Generate CTA rule schema
  - [ ] Run:
    ```bash
    mix phx.gen.schema CTARules.CTARule cta_rules \
      workspace_id:references:workspaces \
      trigger_description:string \
      cta_type:string \
      cta_payload:map \
      priority:integer
    mix ecto.migrate
    ```

- [ ] `T7.2` Build `CTARules` context
  - [ ] Add `list_cta_rules(workspace_id)` ordered by ascending priority.
  - [ ] Add `create_cta_rule(workspace_id, attrs)`.
  - [ ] Add `update_cta_rule(rule, attrs)`.
  - [ ] Add `delete_cta_rule(rule)`.

- [ ] `T7.3` Build CTA Rules LiveView at `/workspaces/:id/cta_rules`
  - [ ] Show existing rules in a sortable table with priority, trigger description, CTA type, and actions.
  - [ ] Add an "Add rule" slide-over form.
  - [ ] Include form fields:
    - [ ] Trigger description textarea with placeholder `"When the buyer asks about price or wants to buy"`.
    - [ ] CTA type select dropdown referencing CTA types in `project.md`.
    - [ ] Dynamic payload fields by CTA type:
      - [ ] `website` → URL field
      - [ ] `phone` → phone number field
      - [ ] `whatsapp` → WhatsApp number field
      - [ ] `reply_buttons` → up to 3 button label inputs
      - [ ] `list_message` → up to 10 item rows with title and description
      - [ ] `location` → latitude and longitude fields
      - [ ] `catalog` → product ID field
      - [ ] `custom` → free-text template field
    - [ ] Priority number auto-filled as the next in sequence.

- [ ] `T7.4` Write CTA rule tests
  - [ ] Test: creating a rule makes it appear in the list.
  - [ ] Test: `cta_injector` formats rules correctly in the system prompt.

---

## TASK GROUP 8 — WhatsApp Playground

- [ ] `T8.1` Build Playground LiveView at `/workspaces/:id/playground`
  - [ ] Match the feel of WhatsApp Web.
  - [ ] Use this layout:
    ```text
    ┌─────────────────────────────────────────┐
    │  [Bot name]  ●  Connected to: endpoint  │
    ├─────────────────────────────────────────┤
    │                                         │
    │   [user bubble right]                   │
    │        [bot bubble left + CTA]          │
    │   [user bubble right]                   │
    │        [bot bubble left + CTA]          │
    │                                         │
    ├─────────────────────────────────────────┤
    │  [ Type a message...          ] [Send]  │
    └─────────────────────────────────────────┘
    ```
  - [ ] Apply styling:
    - [ ] Background `#ECE5DD`
    - [ ] User bubbles `#DCF8C6`, right-aligned
    - [ ] Bot bubbles white, left-aligned, subtle shadow
    - [ ] `system-ui` at `14px`
    - [ ] Timestamps on each bubble

- [ ] `T8.2` Implement Playground LiveView
  - [ ] Use this module shape:
    ```elixir
    defmodule WhatsappbotWeb.PlaygroundLive do
      use WhatsappbotWeb, :live_view

      # mount: load workspace, subscribe to "conversation:playground_#{workspace.id}"
      # handle_event "send_message": call Dispatcher.dispatch(..., :playground), clear input
      # handle_info {:new_message, msg}: stream append message to chat
      # Use LiveView streams for messages (stream :messages)
    end
    ```
  - [ ] Use `phone_number = "playground_#{workspace.id}"` for test sessions.
  - [ ] Add a "Clear chat" button that deletes the playground conversation and starts fresh.
  - [ ] Add a "Copy last reply" icon on bot bubbles.

- [ ] `T8.3` Render CTAs inside playground bubbles
  - [ ] After the bot reply text, render CTA elements as follows:
    - [ ] `website` → blue link button with icon and URL
    - [ ] `phone` → green button with icon and number
    - [ ] `whatsapp` → green button with WhatsApp icon
    - [ ] `reply_buttons` → row of up to 3 tappable chips
    - [ ] `list_message` → expandable list card
    - [ ] `location` → map pin with coordinates
    - [ ] `custom` → italic template text
  - [ ] Make the interactions look as close to real WhatsApp interactive messages as possible.

- [ ] `T8.4` Add a collapsible playground sidebar
  - [ ] Show endpoint data preview as pretty-printed JSON.
  - [ ] Show the last system prompt sent to AI.
  - [ ] Show a running token usage counter for the session.
  - [ ] Add a "Refresh endpoint data" button that forces a re-fetch.

- [ ] `T8.5` Write playground tests
  - [ ] Test: sending a message shows the assistant reply.
  - [ ] Test: CTA appears in the bubble when a rule matches.
  - [ ] Test: clear chat removes the messages.

---

## TASK GROUP 9 — Meta WhatsApp integration

- [ ] `T9.1` Generate MetaConnection schema
  - [ ] Run:
    ```bash
    mix phx.gen.schema Meta.Connection meta_connections \
      workspace_id:references:workspaces \
      phone_number_id:string \
      waba_id:string \
      access_token_encrypted:binary \
      verify_token:string \
      webhook_verified_at:utc_datetime \
      status:string
    mix ecto.migrate
    ```
  - [ ] Auto-generate `verify_token` as a UUID per workspace.

- [ ] `T9.2` Add Cloak encrypted field for `access_token`
  - [ ] Reuse the same pattern as endpoint headers.
  - [ ] Create `Whatsappbot.Encrypted.String`.

- [ ] `T9.3` Build Meta connection LiveView at `/workspaces/:id/meta`
  - [ ] Step 1 — Credentials:
    - [ ] Fields: Phone Number ID, WABA ID, Access Token.
    - [ ] Save sets status to `"pending"`.
  - [ ] Step 2 — Webhook setup:
    - [ ] Show read-only webhook URL `https://yourdomain.com/webhooks/whatsapp/{{workspace.slug}}`.
    - [ ] Show verify token with a copy button.
    - [ ] Add setup instructions for the Meta Developer Console.
  - [ ] Step 3 — Status:
    - [ ] Add a "Verify now" button that sends a test message to Meta.
    - [ ] Show status badge: pending / active / error.
    - [ ] Show an error message if verification fails.

- [ ] `T9.4` Build webhook controller in `lib/whatsappbot_web/controllers/webhook_controller.ex`
  - [ ] Add routes:
    - [ ] `GET /webhooks/whatsapp/:slug` → `handle_verification/2`
    - [ ] `POST /webhooks/whatsapp/:slug` → `handle_message/2`
  - [ ] `handle_verification`:
    - [ ] Read `hub.mode`, `hub.verify_token`, and `hub.challenge`.
    - [ ] Find the workspace by slug.
    - [ ] If the token matches, respond with `hub.challenge` as plain text and set `webhook_verified_at`.
    - [ ] If it does not match, respond with `403`.
  - [ ] `handle_message`:
    - [ ] Parse the incoming JSON body.
    - [ ] Extract `phone_number`, `message_text`, and `message_id`.
    - [ ] Acknowledge immediately with `200`.
    - [ ] Enqueue `Workers.ProcessInboundMessage` with the payload.

- [ ] `T9.5` Add Oban worker `ProcessInboundMessage`
  - [ ] Create `lib/whatsappbot/workers/process_inbound_message.ex`.
  - [ ] Accept `workspace_id`, `phone_number`, `message_text`, and `whatsapp_message_id`.
  - [ ] Call `Dispatcher.dispatch(workspace_id, phone_number, message_text, :whatsapp)`.
  - [ ] On success, call `send_whatsapp_reply(connection, phone_number, reply, cta)`.
  - [ ] On error, log and stop retries after `max_attempts: 3`.

- [ ] `T9.6` Build Meta API sender in `lib/whatsappbot/meta/sender.ex`
  - [ ] Implement `send_message(connection, to_number, reply_text, cta)`.
  - [ ] Return `{:ok, message_id}` or `{:error, reason}`.
  - [ ] Build the correct Meta API payload for each CTA type:
    - [ ] Text only → `{"type": "text", "text": {"body": "..."}}`
    - [ ] `website` / `phone` / `whatsapp` → interactive message with `cta_url` button
    - [ ] `reply_buttons` → interactive `button` type
    - [ ] `list_message` → interactive `list` type
    - [ ] `location` → location message type
  - [ ] POST to `https://graph.facebook.com/v18.0/{{phone_number_id}}/messages`.
  - [ ] Send `Authorization: Bearer {{access_token}}`.

- [ ] `T9.7` Write webhook tests
  - [ ] Test: correct GET verification token returns the challenge.
  - [ ] Test: wrong GET verification token returns `403`.
  - [ ] Test: POST message payload enqueues an Oban job.
  - [ ] Test: Meta sender builds the correct payload for each CTA type.

---

## TASK GROUP 10 — Polish and production readiness

- [ ] `T10.1` Improve navigation and layout
  - [ ] Add top nav with Workspaces link, account name, and logout.
  - [ ] Add breadcrumbs on sub-pages.
  - [ ] Add friendly empty states with a primary CTA button.
  - [ ] Add loading states on all LiveView forms.

- [ ] `T10.2` Improve error handling
  - [ ] Wrap all `Req` HTTP calls in `try/rescue` with user-facing errors.
  - [ ] Show Anthropic API errors in the playground as a red system bubble.
  - [ ] Log webhook processing failures to Oban's built-in error log.
  - [ ] Surface Ecto changeset errors in all forms.

- [ ] `T10.3` Add flash messages
  - [ ] Use consistent flash messages for all create/update/delete actions.
  - [ ] Use `put_flash` with Tailwind-styled alert components.

- [ ] `T10.4` Create environment configuration checklist
  - [ ] Create `.env.example` with:
    ```dotenv
    DATABASE_URL=postgres://user:pass@localhost/whatsappbot_dev
    ENCRYPTION_KEY=<base64 AES-256 key>
    ANTHROPIC_API_KEY=sk-ant-...
    SECRET_KEY_BASE=<mix phx.gen.secret>
    PHX_HOST=localhost
    PORT=4000
    ```

- [ ] `T10.5` Add Fly.io deployment config
  - [ ] Create `fly.toml` with:
    - [ ] app name and region
    - [ ] `http_service` on port `4000`
    - [ ] health check on `/`
    - [ ] env vars `PHX_HOST` and `PORT`
    - [ ] release command `/app/bin/whatsappbot eval "Whatsappbot.Release.migrate"`
  - [ ] Create `lib/whatsappbot/release.ex` with `migrate/0`.

- [ ] `T10.6` Update `README.md`
  - [ ] Add quick-start instructions:
    - [ ] Clone + `deps.get`
    - [ ] Copy `.env.example` to `.env` and fill in values
    - [ ] `mix ecto.setup`
    - [ ] `mix phx.server`
    - [ ] Open `http://localhost:4000`

---

## Implementation order

- [ ] Group 1 (bootstrap) → 1 session
- [ ] Group 2 (auth) → 1 session
- [ ] Group 3 (workspaces) → 1 session
- [ ] Group 4 (endpoints) → 1-2 sessions
- [ ] Group 5 (AI layer) → 1-2 sessions
- [ ] Group 6 (conversations) → 1 session
- [ ] Group 7 (CTA rules) → 1 session
- [ ] Group 8 (playground) → 2 sessions
- [ ] Group 9 (Meta API) → 2 sessions
- [ ] Group 10 (polish) → 1 session

Total estimated: 12-14 Claude Code sessions.

---

## Running commands reference

```bash
# Start dev server
mix phx.server

# Run all tests
mix test

# Run a specific test file
mix test test/whatsappbot/ai/claude_client_test.exs

# Run migrations
mix ecto.migrate

# Roll back one migration
mix ecto.rollback

# Open IEx with app loaded
iex -S mix phx.server

# Generate Cloak encryption key
mix cloak.gen.key AES.GCM 256

# Check Oban queue
Oban.check_queue(:default) |> IO.inspect()
```

---

## Conventions for this project

- [ ] All context modules live in `lib/whatsappbot/` with no web concerns.
- [ ] All LiveViews live in `lib/whatsappbot_web/live/`.
- [ ] PubSub topics use `"conversation:#{id}"` and `"workspace:#{id}"`.
- [ ] All DB queries are scoped to `workspace_id`.
- [ ] Encrypted fields always use `Whatsappbot.Encrypted.*` types.
- [ ] Tests use `Whatsappbot.DataCase` for DB tests and `WhatsappbotWeb.ConnCase` for controller/LiveView tests.
