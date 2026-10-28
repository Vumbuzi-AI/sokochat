defmodule SokochatWeb.WorkspacesLive.Index do
  use SokochatWeb, :live_view

  alias Sokochat.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workspaces")
     |> assign(:workspaces, Workspaces.list_workspaces(socket.assigns.current_user.id))}
  end

  defp language_label("en"), do: "English"
  defp language_label("sw"), do: "Swahili"
  defp language_label(_), do: "English + Swahili"

  defp data_source_label("api"), do: "JSON API"
  defp data_source_label(_), do: "Manual catalog"

  @impl true
  def render(assigns) do
    ~H"""
    <section class="workspace-picker" aria-labelledby="workspaces-title">
      <header class="workspace-picker-header">
        <div class="workspace-picker-heading">
          <p class="workspace-picker-eyebrow">Sokochat</p>
          <h1 id="workspaces-title">Workspaces</h1>
          <p class="workspace-picker-description">
            Manage your businesses and their WhatsApp assistants.
          </p>
        </div>
        <.button :if={@workspaces != []} navigate={~p"/workspaces/new"} variant="secondary">
          <.icon name="hero-plus" class="h-4 w-4" /> New workspace
        </.button>
      </header>

      <%= if @workspaces == [] do %>
        <div class="workspace-picker-empty">
          <div class="workspace-picker-empty-mark" aria-hidden="true">S</div>
          <h2>Your first workspace starts here</h2>
          <p>Add your business, connect your products, and set up your WhatsApp assistant.</p>
          <.button navigate={~p"/workspaces/new"}>
            <.icon name="hero-plus" class="h-4 w-4" /> New workspace
          </.button>
        </div>
      <% else %>
        <div class="workspace-picker-collection">
          <p class="workspace-picker-count">
            {length(@workspaces)} {if length(@workspaces) == 1, do: "workspace", else: "workspaces"}
          </p>
          <div class="workspace-picker-grid">
            <article
              :for={workspace <- @workspaces}
              class="workspace-picker-card"
              aria-labelledby={"workspace-name-#{workspace.id}"}
            >
              <div class="workspace-picker-identity">
                <span class="workspace-picker-avatar" aria-hidden="true">
                  {workspace.name |> String.first() |> String.upcase()}
                </span>
                <div class="workspace-picker-name">
                  <h2 id={"workspace-name-#{workspace.id}"}>{workspace.name}</h2>
                  <p>/{workspace.slug}</p>
                </div>
              </div>

              <dl class="workspace-picker-meta">
                <div>
                  <dt>Language</dt>
                  <dd>{language_label(workspace.language)}</dd>
                </div>
                <div>
                  <dt>Product source</dt>
                  <dd>{data_source_label(workspace.data_source)}</dd>
                </div>
              </dl>

              <details
                :if={workspace.ai_instructions not in [nil, ""]}
                class="workspace-picker-instructions"
              >
                <summary>AI instructions</summary>
                <p>{workspace.ai_instructions}</p>
              </details>
              <p :if={workspace.ai_instructions in [nil, ""]} class="workspace-picker-no-instructions">
                No AI instructions added yet.
              </p>

              <footer class="workspace-picker-footer">
                <p>
                  Updated
                  <time datetime={DateTime.to_iso8601(workspace.updated_at)}>
                    {Calendar.strftime(workspace.updated_at, "%b %-d, %Y")}
                  </time>
                </p>
                <div class="workspace-picker-actions">
                  <.button
                    navigate={~p"/workspaces/#{workspace.id}/edit"}
                    variant="ghost"
                    aria-label={"Edit #{workspace.name}"}
                  >
                    Edit
                  </.button>
                  <.button
                    navigate={~p"/workspaces/#{workspace.id}"}
                    variant="primary"
                    aria-label={"Open #{workspace.name}"}
                  >
                    Open workspace
                  </.button>
                </div>
              </footer>
            </article>
          </div>
        </div>
      <% end %>
    </section>
    """
  end
end
