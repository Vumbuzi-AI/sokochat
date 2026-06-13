defmodule SokochatWeb.HomeLive.Index do
  use SokochatWeb, :live_view

  alias SokochatWeb.HomeLive.Components, as: HomeComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Sokochat"), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <HomeComponents.page />
    """
  end
end
