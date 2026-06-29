# Portals and Routes

Sokochat does not currently implement role-based portals such as admin, staff, doctor, pharmacy, or supplier sections. The only application role encoded in the data model is an authenticated user who owns workspaces. TODO: add a role field and authorization rules before documenting separate role portals.

## Public Website

Audience: anonymous visitors and signed-in users.

Routes:

- `GET /` -> `SokochatWeb.HomeLive.Index`

Purpose: marketing/home page for the product. It runs in the `:marketing` live session with `SokochatWeb.UserAuth` mounted as `:mount_current_user`.

## Account Portal

Audience: anonymous users creating or recovering accounts, and authenticated users managing settings.

Routes:

- `GET /users/register` -> `SokochatWeb.UserRegistrationController.new/2`
- `POST /users/register` -> `SokochatWeb.UserRegistrationController.create/2`
- `GET /users/log_in` -> `SokochatWeb.UserSessionController.new/2`
- `POST /users/log_in` -> `SokochatWeb.UserSessionController.create/2`
- `DELETE /users/log_out` -> `SokochatWeb.UserSessionController.delete/2`
- `GET /users/reset_password` -> `SokochatWeb.UserResetPasswordController.new/2`
- `POST /users/reset_password` -> `SokochatWeb.UserResetPasswordController.create/2`
- `GET /users/reset_password/:token` -> `SokochatWeb.UserResetPasswordController.edit/2`
- `PUT /users/reset_password/:token` -> `SokochatWeb.UserResetPasswordController.update/2`
- `GET /users/settings` -> `SokochatWeb.UserSettingsController.edit/2`
- `PUT /users/settings` -> `SokochatWeb.UserSettingsController.update/2`
- `GET /users/settings/confirm_email/:token` -> `SokochatWeb.UserSettingsController.confirm_email/2`
- `GET /users/confirm` -> `SokochatWeb.UserConfirmationController.new/2`
- `POST /users/confirm` -> `SokochatWeb.UserConfirmationController.create/2`
- `GET /users/confirm/:token` -> `SokochatWeb.UserConfirmationController.edit/2`
- `POST /users/confirm/:token` -> `SokochatWeb.UserConfirmationController.update/2`

## Workspace Owner Portal

Audience: authenticated workspace owners.

Live session: `:require_authenticated_user` with `SokochatWeb.UserAuth` mounted as `:ensure_authenticated`.

Routes:

- `GET /workspaces` -> `SokochatWeb.WorkspacesLive.Index`
- `GET /workspaces/new` -> `SokochatWeb.WorkspacesLive.Form` with `:new`
- `GET /workspaces/:id` -> `SokochatWeb.WorkspacesLive.Setup` with `:setup`
- `GET /workspaces/:id/edit` -> `SokochatWeb.WorkspacesLive.Form` with `:edit`
- `GET /workspaces/:id/endpoint` -> `SokochatWeb.WorkspacesLive.Endpoint`
- `GET /workspaces/:id/cta_rules` -> `SokochatWeb.WorkspacesLive.CTARules`
- `GET /workspaces/:id/playground` -> `SokochatWeb.PlaygroundLive`
- `GET /workspaces/:id/meta` -> `SokochatWeb.WorkspacesLive.Meta`

Main screens and actions:

- Workspace list and creation
- Business profile editing
- Manual catalog model, fields, and items
- JSON endpoint configuration and connection tests
- CTA rule creation, update, sorting, deletion, and AI recommendations
- Browser playground chat with persisted conversation messages
- Meta credentials and webhook setup checklist

Authorization note: LiveViews fetch workspaces by both workspace id and `current_user.id`, so users can only access their own workspaces.

## API and Webhooks

Audience: local demos, Meta WhatsApp Cloud API, and background integrations.

Routes:

- `GET /api/test/products` -> `SokochatWeb.ProductController.index/2`
- `GET /webhooks/whatsapp/:slug` -> `SokochatWeb.WebhookController.handle_verification/2`
- `POST /webhooks/whatsapp/:slug` -> `SokochatWeb.WebhookController.handle_message/2`

Webhook verification looks up the Meta connection by workspace slug and compares Meta's verify token. Inbound webhook messages enqueue `Sokochat.Workers.ProcessInboundMessage`.

## Development Tools

Audience: developers in `:dev`.

Routes, when `config :sokochat, dev_routes: true`:

- `GET /dev/dashboard` -> Phoenix LiveDashboard
- `/dev/mailbox` -> `Plug.Swoosh.MailboxPreview`
