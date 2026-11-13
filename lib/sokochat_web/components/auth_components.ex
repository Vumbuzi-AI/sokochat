defmodule SokochatWeb.AuthComponents do
  @moduledoc """
  Page layouts shared by marketing and auth screens: the site header, the
  split auth layout (Log in, Create account) and the centred auth card
  (forgot, reset, confirm, resend).
  """
  use SokochatWeb, :verified_routes
  use Phoenix.Component

  import SokochatWeb.CoreComponents

  @doc """
  Renders the 56px marketing header: logo left, actions right.
  """
  slot :inner_block

  def site_header(assigns) do
    ~H"""
    <header class="soko-site-header flex h-14 items-center justify-between px-4 sm:px-8">
      <.link navigate={~p"/"} aria-label="Sokochat home">
        <img src={~p"/images/logo.png"} alt="Sokochat" class="block h-[34px] w-auto" />
      </.link>
      <nav class="flex items-center gap-5">{render_slot(@inner_block)}</nav>
    </header>
    """
  end

  @doc """
  Renders the split auth layout: form on white, Stage with an eyebrow,
  a 44px headline and one photo on the right. On phones the Stage sits on
  top in a shorter form.
  """
  attr :label, :string, required: true, doc: "mono caps label above the title"
  attr :title, :string, required: true
  attr :eyebrow, :string, required: true
  attr :headline, :string, required: true

  slot :subtitle
  slot :inner_block, required: true
  slot :stage, required: true, doc: "photo and notes under the headline"
  slot :aside, doc: "content under the headline; moves the photo into a full-height right column"

  def auth_split(assigns) do
    ~H"""
    <main class="grid min-h-dvh bg-soko-white lg:grid-cols-[minmax(0,1fr)_minmax(0,1.24fr)]">
      <section class="order-2 flex flex-col px-6 pb-8 pt-6 sm:px-16 lg:order-1 lg:pt-10">
        <.link navigate={~p"/"} class="hidden lg:block" aria-label="Sokochat home">
          <img src={~p"/images/logo.png"} alt="Sokochat" class="h-9 w-auto" />
        </.link>
        <div class="flex flex-1 flex-col justify-center py-10">
          <div class="w-full max-w-[400px]">
            <p class="soko-mono text-soko-ink-3">{@label}</p>
            <h1 class="soko-heading mt-3 text-[32px]">{@title}</h1>
            <p :if={@subtitle != []} class="mt-2 text-base text-soko-ink-2">
              {render_slot(@subtitle)}
            </p>
            <div class="mt-8">{render_slot(@inner_block)}</div>
          </div>
        </div>
        <p class="text-xs text-soko-ink-3">Sokochat · WhatsApp sales for shops in Kenya</p>
      </section>

      <section class="order-1 p-2 sm:p-4 lg:order-2">
        <div class={[
          "h-full gap-6 rounded-soko-28 bg-soko-stage p-4 pt-6 sm:p-12 sm:pb-4 lg:min-h-[calc(100dvh-32px)]",
          @aside != [] && "grid lg:grid-cols-2 lg:p-4 lg:pl-12 lg:pt-12",
          @aside == [] && "flex flex-col"
        ]}>
          <img src={~p"/images/logo.png"} alt="Sokochat" class="h-8 w-auto self-start lg:hidden" />
          <div class="flex flex-col items-start gap-5 sm:pr-8">
            <span class="soko-eyebrow">{@eyebrow}</span>
            <p class="soko-display max-w-[16ch] text-[32px] sm:text-[44px]">{@headline}</p>
            <div :if={@aside != []} class="mt-auto hidden w-full pt-8 lg:block">
              {render_slot(@aside)}
            </div>
          </div>
          <div class={[
            "relative min-h-[220px] flex-1 sm:min-h-[420px]",
            @aside != [] && "lg:min-h-0"
          ]}>
            {render_slot(@stage)}
          </div>
        </div>
      </section>
    </main>
    """
  end

  @doc """
  Renders the centred auth layout: site header, Stage, and a 480px white
  card with an icon tile, title and text.
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :tone, :string, default: "default", values: ~w(default danger)

  slot :inner_block, required: true
  slot :footer

  def auth_card(assigns) do
    ~H"""
    <main class="flex min-h-dvh flex-col gap-2 bg-soko-white p-2 sm:gap-4 sm:p-4">
      <.site_header>
        <.link navigate={~p"/users/log_in"} class="text-sm font-medium">Log in</.link>
        <.button navigate={~p"/users/register"} tone="secondary" size="sm">Create account</.button>
      </.site_header>
      <section class="grid flex-1 place-items-center rounded-soko-28 bg-soko-stage p-4 sm:p-12">
        <div class="flex w-full max-w-[480px] flex-col gap-7 rounded-soko-20 border border-soko-line bg-soko-white p-6 sm:p-10">
          <div class="flex flex-col gap-4">
            <span class={[
              "grid h-11 w-11 place-items-center rounded-[12px]",
              @tone == "danger" && "bg-soko-danger-wash text-soko-danger",
              @tone == "default" && "bg-soko-mint-wash text-soko-forest"
            ]}>
              <.icon name={@icon} class="h-[22px] w-[22px]" />
            </span>
            <div class="flex flex-col gap-2">
              <h1 class="soko-heading text-[28px]">{@title}</h1>
              <p :if={@text} class="text-base text-soko-ink-2">{@text}</p>
            </div>
          </div>
          {render_slot(@inner_block)}
          <p :if={@footer != []} class="text-sm text-soko-ink-2">{render_slot(@footer)}</p>
        </div>
      </section>
    </main>
    """
  end

  @doc """
  Renders a standalone page outside the desk: logo and breadcrumb on
  white, content on the Stage. Used by workspace setup and account-level
  pages.
  """
  attr :title, :string, required: true
  attr :current_user, :map, default: nil
  attr :back, :string, default: nil, doc: "breadcrumb parent path"
  attr :back_label, :string, default: "Workspaces"
  attr :center, :boolean, default: false
  slot :inner_block, required: true

  def stage_page(assigns) do
    ~H"""
    <div class="flex min-h-dvh flex-col gap-2 bg-soko-white p-2 sm:gap-4 sm:p-4">
      <header class="soko-site-header flex h-14 items-center gap-6 px-4 sm:px-6">
        <.link navigate={~p"/workspaces"} aria-label="Sokochat home">
          <img src={~p"/images/logo.png"} alt="Sokochat" class="block h-[34px] w-auto" />
        </.link>
        <nav class="flex min-w-0 items-center gap-2 text-sm" aria-label="Breadcrumb">
          <.link navigate={@back || ~p"/workspaces"} class="text-soko-ink-3 hover:text-soko-ink">
            {@back_label}
          </.link>
          <span class="text-soko-ink-3">/</span>
          <span class="truncate font-medium">{@title}</span>
        </nav>
        <.link
          :if={@current_user}
          navigate={~p"/users/settings"}
          class="ml-auto"
          title={"#{user_name(@current_user)} · Account settings"}
        >
          <.avatar seed={@current_user.email} size="lg" label={user_name(@current_user)} />
        </.link>
      </header>
      <main class={[
        "flex-1 rounded-soko-28 bg-soko-stage p-4 sm:p-8",
        @center && "grid place-items-center"
      ]}>
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  defp user_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp user_name(%{email: email}), do: email

  @doc """
  Renders the eye button that shows and hides a password field. Put it in
  the `:trailing` slot of a password input.
  """
  attr :for, :string, required: true

  def password_toggle(assigns) do
    ~H"""
    <button
      type="button"
      data-password-toggle
      aria-controls={@for}
      aria-pressed="false"
      aria-label="Show password"
      class="grid h-6 w-6 place-items-center text-soko-ink-3 hover:text-soko-ink"
    >
      <.icon name="eye" data-icon="show" class="hidden h-[18px] w-[18px]" />
      <.icon name="eye-slash" data-icon="hide" class="h-[18px] w-[18px]" />
    </button>
    """
  end
end
