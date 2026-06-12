defmodule WhatsappbotWeb.WorkspacesLive.Index do
  use WhatsappbotWeb, :live_view

  alias Whatsappbot.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workspaces")
     |> assign(:workspaces, Workspaces.list_workspaces(socket.assigns.current_user.id))}
  end

  defp language_label("en"), do: "English only"
  defp language_label("sw"), do: "Swahili only"
  defp language_label(_), do: "English + Swahili"

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="space-y-2">
        <p class="text-[11px] font-bold uppercase tracking-[1.2px] text-brand-light">Workspaces</p>
        <h1 class="text-[30px] font-bold tracking-tight text-ink">Your bots</h1>
        <p class="max-w-2xl text-[15px] leading-6 text-ink-muted">
          Each bot connects one business to WhatsApp — its own data source, rules, and AI instructions.
        </p>
      </div>

      <%= if @workspaces == [] do %>
        <div class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          <.new_workspace_card />
        </div>
      <% else %>
        <div class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          <article
            :for={workspace <- @workspaces}
            class="group flex h-full flex-col rounded-xl border border-line bg-surface p-6 shadow-card transition duration-[180ms] ease-[cubic-bezier(0.4,0,0.2,1)] hover:-translate-y-0.5 hover:shadow-panel"
          >
            <div class="flex items-center gap-2">
              <span class="rounded-full border border-[#B3D4F5] bg-[#EAF4FF] px-2.5 py-0.5 text-[11px] font-semibold tracking-[0.3px] text-[#0A6EBD]">
                {language_label(workspace.language)}
              </span>
            </div>

            <h2 class="mt-2.5 text-[17px] font-semibold text-ink">{workspace.name}</h2>
            <p class="mt-1">
              <span class="rounded bg-surface-alt px-1.5 py-0.5 font-mono text-xs text-ink-faint">
                /{workspace.slug}
              </span>
            </p>
            <p class="mt-2 line-clamp-2 text-sm leading-6 text-ink-muted">
              {workspace.ai_instructions || "No AI instructions added yet."}
            </p>

            <div class="my-4 border-t border-line"></div>

            <div class="mt-auto flex items-center justify-between">
              <p class="text-[13px] text-ink-faint">
                Updated {Calendar.strftime(workspace.updated_at, "%b %d, %Y")}
              </p>
              <.link
                navigate={~p"/workspaces/#{workspace.id}"}
                class="inline-flex items-center rounded-full bg-brand-dark px-5 py-2 text-[13px] font-semibold text-white transition hover:bg-brand-mid"
              >
                Open
              </.link>
            </div>
          </article>

          <.new_workspace_card />
        </div>
      <% end %>
    </section>
    """
  end

  defp new_workspace_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/workspaces/new"}
      class="group flex min-h-[200px] flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed border-line bg-surface/40 p-6 text-center transition duration-[180ms] hover:border-brand-light"
    >
      <span class="text-3xl font-light text-ink-faint transition group-hover:text-brand-dark">+</span>
      <span class="text-sm font-medium text-ink-muted transition group-hover:text-brand-dark">
        New workspace
      </span>
    </.link>
    """
  end
end
