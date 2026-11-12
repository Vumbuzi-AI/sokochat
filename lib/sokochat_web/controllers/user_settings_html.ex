defmodule SokochatWeb.UserSettingsHTML do
  use SokochatWeb, :html

  embed_templates "user_settings_html/*"

  attr :email_changeset, :any, required: true
  attr :password_changeset, :any, required: true

  def settings_body(assigns) do
    ~H"""
    <div class="flex max-w-[880px] flex-col">
      <.section
        title="Appearance"
        text="Choose how your desk looks on this device. System follows the setting on this device."
      >
        <div id="appearance" data-appearance phx-update="ignore">
          <.segmented
            name="appearance"
            value="system"
            label="Appearance"
            options={[{"System", "system"}, {"Light", "light"}, {"Dark", "dark"}]}
          />
        </div>
      </.section>

      <.section
        title="Email address"
        text="Change the email you log in with. We'll send a link to the new address and the change applies once you confirm it."
      >
        <.simple_form :let={f} for={@email_changeset} action={~p"/users/settings"} id="update_email">
          <.banner :if={@email_changeset.action} tone="danger">
            Some details need another look. Check the fields below.
          </.banner>
          <input type="hidden" name="action" value="update_email" />
          <.input field={f[:email]} type="email" label="Email" autocomplete="email" required />
          <.input
            field={f[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_email"
            value=""
            autocomplete="current-password"
            required
          >
            <:trailing><.password_toggle for="current_password_for_email" /></:trailing>
          </.input>
          <div>
            <.button tone="secondary" size="sm" phx-disable-with="Changing">Change email</.button>
          </div>
        </.simple_form>
      </.section>

      <.section
        title="Password"
        text="Use at least 6 characters. You stay logged in on this device after the change."
      >
        <.simple_form
          :let={f}
          for={@password_changeset}
          action={~p"/users/settings"}
          id="update_password"
        >
          <.banner :if={@password_changeset.action} tone="danger">
            Some details need another look. Check the fields below.
          </.banner>
          <input type="hidden" name="action" value="update_password" />
          <.input
            field={f[:password]}
            type="password"
            label="New password"
            value=""
            autocomplete="new-password"
            required
          >
            <:trailing><.password_toggle for="user_password" /></:trailing>
          </.input>
          <.input
            field={f[:password_confirmation]}
            type="password"
            label="Confirm new password"
            value=""
            autocomplete="new-password"
            required
          />
          <.input
            field={f[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value=""
            autocomplete="current-password"
            required
          >
            <:trailing><.password_toggle for="current_password_for_password" /></:trailing>
          </.input>
          <div>
            <.button tone="secondary" size="sm" phx-disable-with="Changing">Change password</.button>
          </div>
        </.simple_form>
      </.section>
    </div>
    """
  end
end
