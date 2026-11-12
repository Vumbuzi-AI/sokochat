defmodule SokochatWeb.HomeLive.Index do
  use SokochatWeb, :live_view

  alias SokochatWeb.HomeLive.Components, as: HomeComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Turn WhatsApp chats into orders", marketing: true),
     layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <HomeComponents.page current_user={@current_user} />
    """
  end
end
