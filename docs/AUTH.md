# Authentication

Sokochat uses the standard Phoenix generated email/password authentication flow with session tokens stored in the database.

## User Model

Schema: `Sokochat.Accounts.User`

Fields:

- `name`
- `email`
- `password` virtual field
- `hashed_password`
- `current_password` virtual field
- `confirmed_at`
- timestamps

Tokens are stored in `Sokochat.Accounts.UserToken` with `token`, `context`, `sent_to`, `user_id`, and `inserted_at`.

## Login Flow

1. `SokochatWeb.UserSessionController.create/2` receives email, password, and optional remember-me params.
2. `Sokochat.Accounts.get_user_by_email_and_password/2` validates credentials with Bcrypt.
3. `SokochatWeb.UserAuth.log_in_user/3` generates a session token through `Sokochat.Accounts.generate_user_session_token/1`.
4. The token is stored in the signed session, and optionally in the remember-me cookie.
5. `fetch_current_user/2` loads the user from the session token on later browser requests.

## Plugs and LiveView Hooks

`SokochatWeb.Router` imports `SokochatWeb.UserAuth`.

Browser pipeline:

- `fetch_current_user` runs for normal browser requests.

Auth route pipeline:

- `redirect_if_user_is_authenticated` prevents signed-in users from seeing registration/login/reset routes.

Protected controller routes:

- `require_authenticated_user` protects user settings.

LiveView hooks:

- `on_mount(:mount_current_user, ...)` assigns `:current_user` when present.
- `on_mount(:ensure_authenticated, ...)` redirects unauthenticated users to `/users/log_in`.
- `on_mount(:redirect_if_user_is_authenticated, ...)` redirects signed-in users away from auth screens.

## Authorization

There is no role column or permissions table. The practical authorization boundary is workspace ownership:

- Workspace LiveViews call `Sokochat.Workspaces.get_workspace!(id, current_user.id)`.
- That query requires both the workspace id and the signed-in user's id.
- Users cannot access other users' workspace setup pages unless the database ownership check is bypassed.

TODO: add roles and role-to-route policies if the product needs staff/admin/team portals.

## PIN or Secondary Auth

No PIN, MFA, or secondary authentication mechanism is present in the current codebase.

## Adding a New Role

Roles are not implemented yet. A maintainable role rollout would need:

1. A migration adding a role field or a membership table.
2. Schema validations in `Sokochat.Accounts.User` or a new membership schema.
3. Context APIs that check role/membership before returning records.
4. Router pipelines or LiveView `on_mount` hooks for role gates.
5. Tests covering allowed and denied access for each route.
