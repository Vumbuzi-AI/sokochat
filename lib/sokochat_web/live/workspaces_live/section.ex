defmodule SokochatWeb.WorkspacesLive.Section do
  use SokochatWeb, :live_view

  alias Sokochat.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:page_title, page_title(socket.assigns.live_action))}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp page_title(:endpoint), do: "Data Ingestion"
  defp page_title(:cta_rules), do: "CTA Rules"
  defp page_title(:playground), do: "Playground"
  defp page_title(:meta), do: "Meta Connection"

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={assigns[:workspace]} class="mx-auto max-w-3xl space-y-6">
      <nav class="flex items-center gap-1.5 text-[13px] text-n500">
        <.link navigate={~p"/workspaces"} class="transition hover:text-n400">Workspaces</.link>
        <span>/</span>
        <.link navigate={~p"/workspaces/#{@workspace.id}"} class="transition hover:text-n400">
          {@workspace.name}
        </.link>
        <span>/</span>
        <span class="text-n400">{@page_title}</span>
      </nav>

      <div class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]">
        <div class="space-y-1.5 border-b border-n300 px-8 py-6">
          <h1 class="text-[22px] font-bold tracking-tight text-n900">{@page_title}</h1>
          <p class="text-sm leading-6 text-n400">
            This section is scaffolded so the dashboard flow is complete. The detailed configuration arrives in the next task group.
          </p>
        </div>

        <div class="px-8 py-6">
          <div class="flex items-start gap-3 rounded-lg border border-n300 bg-n200 px-5 py-4 text-sm leading-6 text-n400">
            <.icon name="hero-wrench-screwdriver" class="mt-0.5 h-5 w-5 flex-none text-primary" />
            <div>
              <p class="font-medium text-n900">Coming soon</p>
              <p class="mt-1">
                The workspace route and ownership checks are in place. Continue from the dashboard once the next setup step is implemented.
              </p>
            </div>
          </div>

          <.link
            navigate={~p"/workspaces/#{@workspace.id}"}
            class="mt-6 inline-flex items-center gap-1 text-sm font-semibold text-primary hover:underline"
          >
            <.icon name="hero-arrow-left-mini" class="h-4 w-4" /> Back to dashboard
          </.link>
        </div>
      </div>
    </section>
    """
  end
end
