defmodule SokochatWeb.HomeLive.Components do
  @moduledoc """
  Marketing page. Follows "Hero · v2" on the Doop canvas (Landing page).
  """
  use SokochatWeb, :html

  alias SokochatWeb.MarketingComponents

  attr :current_user, :map, default: nil

  def page(assigns) do
    ~H"""
    <div id="top" class="flex min-h-dvh flex-col gap-2 bg-soko-white p-2 sm:gap-4 sm:p-4">
      <.nav current_user={@current_user} />
      <.hero current_user={@current_user} />
      <.facts />
      <MarketingComponents.footer current_user={@current_user} />
    </div>
    """
  end

  attr :current_user, :map, default: nil

  def nav(assigns) do
    ~H"""
    <.site_header>
      <%= if @current_user do %>
        <.link
          navigate={~p"/users/settings"}
          class="hidden max-w-[220px] truncate text-sm text-soko-ink-2 hover:text-soko-ink sm:block"
        >
          {@current_user.email}
        </.link>
        <.link href={~p"/users/log_out"} method="delete" class="text-sm font-medium">Log out</.link>
        <.button navigate={~p"/workspaces"} tone="dark" size="sm">Open your desk</.button>
      <% else %>
        <.link navigate={~p"/users/log_in"} class="text-sm font-medium">Sign in</.link>
        <.button navigate={~p"/users/register"} tone="dark" size="sm" class="hidden sm:inline-flex">
          List your shop
        </.button>
      <% end %>
    </.site_header>
    """
  end

  attr :current_user, :map, default: nil

  defp hero(assigns) do
    ~H"""
    <section class="flex flex-col items-center rounded-soko-28 bg-soko-stage px-2 pb-2 pt-10 sm:px-4 sm:pb-4 sm:pt-[88px]">
      <div class="flex max-w-[1000px] flex-col items-center gap-6 px-2 text-center">
        <span class="soko-eyebrow">For businesses</span>
        <h1 class="soko-display text-[44px] sm:text-[64px] lg:text-[84px]">
          Turn WhatsApp chats<br class="hidden sm:inline" /> into orders
        </h1>
        <p class="max-w-[46ch] text-base text-soko-ink-2 [text-wrap:balance] sm:text-lg">
          AI answers customers from your catalogue, automatically or after you approve each reply.
        </p>
        <div class="mt-2 flex w-full flex-col gap-3 sm:w-auto sm:flex-row">
          <.button
            navigate={if @current_user, do: ~p"/workspaces", else: ~p"/users/register"}
            size="lg"
          >
            <.icon name="storefront" /> List your shop
          </.button>
          <.button href="#how-it-works" tone="secondary" size="lg">See how it works</.button>
        </div>
      </div>

      <div class="relative mt-12 h-[340px] w-full overflow-hidden rounded-soko-20 sm:mt-[72px] sm:h-[520px] lg:h-[640px]">
        <img
          src={~p"/images/people-phone.jpg"}
          alt="Two friends laughing together while looking at a phone"
          class="absolute inset-0 h-full w-full object-cover object-[50%_30%]"
        />
        <.order_note
          class="absolute inset-x-3 bottom-3 !w-auto sm:inset-x-auto sm:bottom-auto sm:left-7 sm:top-7 sm:!w-[296px]"
          photo={~p"/images/cherry-case.webp"}
          title="New order"
          meta="Cherry phone case"
          badge="Paid"
          foot_left="Order 1042"
          foot_right="KES 1,200"
        />
        <.stat_note
          class="absolute right-7 top-24 hidden md:flex"
          label="Asked this week"
          value="14 people"
          caption="Phone cases"
        />
        <article class="absolute bottom-7 right-7 hidden w-[300px] flex-col gap-2.5 rounded-2xl border border-soko-line bg-soko-white px-4 py-3.5 lg:flex">
          <div class="flex items-center gap-2.5">
            <.avatar seed={2} size="sm" />
            <strong class="flex-1 text-sm font-medium">Review waiting</strong>
            <span class="text-xs text-soko-ink-2">Cherry phone case</span>
          </div>
          <p class="text-sm">Arrived the next day. The colour matches the photo.</p>
        </article>
        <.sample_tag class="absolute left-3 top-3 !bg-soko-white sm:left-7 sm:top-auto sm:bottom-7" />
      </div>
    </section>
    """
  end

  defp facts(assigns) do
    ~H"""
    <section
      id="how-it-works"
      class="grid gap-8 px-4 pb-12 pt-6 sm:px-8 md:grid-cols-3 md:gap-12 md:px-16 md:pb-12 md:pt-10"
    >
      <div
        :for={
          {icon, title, text} <- [
            {"chat-text", "One WhatsApp number", "Buyers message your shop on a single line."},
            {"package", "Replies from your catalogue",
             "Sokochat answers with the products and prices you added."},
            {"storefront", "Orders on your desk", "Paid orders and open questions wait in one place."}
          ]
        }
        class="flex items-start gap-3.5"
      >
        <span class="grid h-9 w-9 flex-none place-items-center rounded-[10px] bg-soko-stage text-soko-forest">
          <.icon name={icon} class="h-[18px] w-[18px]" />
        </span>
        <span class="flex flex-col gap-1">
          <strong class="text-base font-medium">{title}</strong>
          <span class="text-sm text-soko-ink-2">{text}</span>
        </span>
      </div>
    </section>
    """
  end
end
