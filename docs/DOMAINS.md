# Domains

This file enumerates every context or bounded domain in `lib/sokochat/`.

## Accounts

Module: `Sokochat.Accounts`

Responsibility: user registration, authentication lookup, email changes, password changes, confirmation, reset password, and session tokens.

Schemas:

- `Sokochat.Accounts.User` -> `users`
- `Sokochat.Accounts.UserToken` -> `users_tokens`

Key public functions:

- `get_user_by_email/1`
- `get_user_by_email_and_password/2`
- `get_user!/1`
- `register_user/1`
- `change_user_registration/2`
- `apply_user_email/3`
- `update_user_email/2`
- `update_user_password/3`
- `generate_user_session_token/1`
- `get_user_by_session_token/1`
- `delete_user_session_token/1`
- `deliver_user_confirmation_instructions/2`
- `confirm_user/1`
- `deliver_user_reset_password_instructions/2`
- `get_user_by_reset_password_token/1`
- `reset_user_password/2`

Relations: users own workspaces through `workspaces.account_id`; session and email tokens belong to users.

## Workspaces

Module: `Sokochat.Workspaces`

Responsibility: create, list, update, and delete business workspaces for a signed-in user.

Schema:

- `Sokochat.Workspaces.Workspace` -> `workspaces`

Key public functions:

- `list_workspaces/1`
- `get_workspace!/2`
- `create_workspace/2`
- `update_workspace/2`
- `delete_workspace/1`
- `change_workspace/2`

Relations: a workspace belongs to one user and owns one endpoint, one manual catalog, many CTA rules, many conversations, and one Meta connection.

## Catalogs

Module: `Sokochat.Catalogs`

Responsibility: manual catalog model, custom fields, item curation, workspace AI context building, and category lookup.

Schemas:

- `Sokochat.Catalogs.Catalog` -> `catalogs`
- `Sokochat.Catalogs.Field` -> `catalog_fields`
- `Sokochat.Catalogs.Item` -> `catalog_items`

Key public functions:

- `get_catalog/1`
- `get_catalog_or_new/1`
- `upsert_catalog/2`
- `change_catalog/2`
- `list_fields/1`
- `list_items/1`
- `get_item!/2`
- `get_field!/2`
- `upsert_field/2`
- `delete_field/1`
- `upsert_item/2`
- `delete_item/1`
- `build_workspace_context/3`
- `catalog_configured?/1`
- `list_item_categories/1`
- `item_context/1`
- `field_input_type/1`
- `canonical_item_keys/0`

Relations: catalogs belong to workspaces; fields and items belong to catalogs. Saving items enqueues `Sokochat.Workers.EmbedCatalogItem`.

## Endpoints

Module: `Sokochat.Endpoints`

Responsibility: configure a workspace JSON endpoint, fetch live data, cache responses, and broadcast refreshes.

Schema:

- `Sokochat.Endpoints.Endpoint` -> `endpoints`

Key public functions:

- `get_endpoint/1`
- `list_endpoints_for_refresh_strategy/1`
- `upsert_endpoint/2`
- `change_endpoint/2`
- `fetch_live_data/1`
- `refresh_cached_data/1`
- `subscribe_workspace/1`
- `endpoint_topic/1`

Relations: one endpoint belongs to one workspace. Headers are encrypted with `Sokochat.Encrypted.Map`.

## CTA Rules

Module: `Sokochat.CTARules`

Responsibility: manage CTA rules that tell the assistant when to attach website, phone, WhatsApp, reply button, list, location, catalog, or custom actions.

Schemas:

- `Sokochat.CTARules.CTARule` -> `cta_rules`
- `Sokochat.CTARules.RuleForm` -> embedded form schema for CTA-specific payload fields

Key public functions:

- `list_cta_rules/1`
- `get_cta_rule!/2`
- `create_cta_rule/2`
- `update_cta_rule/2`
- `delete_cta_rule/1`
- `change_cta_rule/2`
- `next_priority/1`

Relations: CTA rules belong to workspaces and are injected into AI prompts by `Sokochat.AI.CtaInjector`.

## Conversations

Module: `Sokochat.Conversations`

Responsibility: create or reuse conversations, store messages, build message history, and broadcast playground updates.

Schemas:

- `Sokochat.Conversations.Conversation` -> `conversations`
- `Sokochat.Conversations.Message` -> `messages`

Key public functions:

- `get_conversation/3`
- `get_or_create_conversation/3`
- `list_conversations/1`
- `get_conversation!/2`
- `add_message/4`
- `list_messages/1`
- `delete_conversation/1`
- `build_messages/2`
- `subscribe_conversation/1`
- `subscribe_playground/1`
- `broadcast_new_message/1`
- `broadcast_playground_message/2`
- `broadcast_playground_cleared/1`
- `conversation_topic/1`
- `playground_phone_number/1`
- `playground_topic/1`

Related modules:

- `Sokochat.Conversations.Dispatcher` prepares workspace data, calls OpenAI, stores user/assistant messages, and broadcasts playground replies.
- `Sokochat.Conversations.ProductCTA` enriches replies with product CTAs from catalog or endpoint data.

Relations: conversations belong to workspaces; messages belong to conversations.

## Meta

Module: `Sokochat.Meta`

Responsibility: store WhatsApp Cloud API connection details and update webhook status.

Schema:

- `Sokochat.Meta.Connection` -> `meta_connections`

Key public functions:

- `get_connection/1`
- `get_connection_by_workspace_slug/1`
- `get_connection_or_new/1`
- `change_connection/2`
- `upsert_connection/2`
- `mark_verified/1`
- `mark_error/2`

Related module:

- `Sokochat.Meta.Sender` builds and sends WhatsApp Cloud API messages.

Relations: one Meta connection belongs to one workspace. Access tokens are encrypted with `Sokochat.Encrypted.String`.

## AI

Modules:

- `Sokochat.AI.ContextBuilder`
- `Sokochat.AI.CtaInjector`
- `Sokochat.AI.CtaRecommender`
- `Sokochat.AI.Embedder`
- `Sokochat.AI.OpenAIClient`
- `Sokochat.AI.Retriever`

Responsibility: generate prompts, call OpenAI Responses and Embeddings APIs, parse structured CTA recommendations, and retrieve relevant catalog items.

Relations: used by conversation dispatching, CTA recommendation UI, and embedding workers.

## Workers

Modules:

- `Sokochat.Workers.EndpointRefreshWorker`
- `Sokochat.Workers.ProcessInboundMessage`
- `Sokochat.Workers.EmbedCatalogItem`

Responsibility: scheduled endpoint refreshes, queued inbound WhatsApp message processing, and catalog embedding generation.

Relations: configured through Oban in `config/config.exs`.

## Infrastructure

Modules:

- `Sokochat.Repo`
- `Sokochat.Vault`
- `Sokochat.PostgrexTypes`
- `Sokochat.Mailer`
- `Sokochat.Application`

Responsibility: database access, encryption, pgvector type registration, email delivery, and supervision tree setup.
