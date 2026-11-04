defmodule SokochatWeb.WorkspaceShell do
  @moduledoc false
  use SokochatWeb, :html

  attr :workspace, :map, required: true
  attr :workspaces, :list, default: []
  attr :current_user, :map, required: true
  attr :tab, :atom, required: true
  attr :title, :string, required: true
  attr :flash, :map, default: %{}
  slot :actions
  slot :inner_block, required: true

  def shell(assigns) do
    assigns =
      assign(assigns,
        sections: nav_sections(assigns.workspace.id),
        active: Atom.to_string(assigns.tab)
      )

    ~H"""
    <div
      id={"workspace-#{@workspace.id}"}
      phx-hook="DashboardShell"
      data-workspace-id={@workspace.id}
      data-storage-key="sokochat-dashboard-sidebar-width"
      data-default-width="220"
      data-min-width="180"
      data-max-width="320"
      class="obsidian-dashboard-shell"
    >
      <.flash_group flash={@flash} />

      <aside id="workspace-sidebar" data-sidebar class="dash-sidebar">
        <.sidebar
          list="dock"
          workspace={@workspace}
          workspaces={@workspaces}
          tab={@tab}
          sections={@sections}
          active={@active}
          account={@current_user.email}
        />
        <div
          data-resize
          role="separator"
          aria-orientation="vertical"
          aria-label="Resize sidebar"
          aria-controls="workspace-sidebar"
          tabindex="0"
          class="dash-resize"
        >
          <span class="dash-resize-line" aria-hidden="true"></span>
        </div>
      </aside>

      <section data-panel class="dash-panel" aria-labelledby="workspace-title">
        <header class="dash-header">
          <div class="dash-header-row">
            <div class="dash-heading">
              <.button
                type="button"
                data-menu
                variant="secondary"
                size="icon"
                class="dash-menu-btn"
                aria-label="Open navigation"
                aria-expanded="false"
              >
                <span class="dash-nav-icon" aria-hidden="true">
                  <.icon name="hero-bars-3" class="h-4 w-4" />
                </span>
              </.button>
              <h1 id="workspace-title" class="dash-title">{@title}</h1>
            </div>
            <div class="dash-header-actions">{render_slot(@actions)}</div>
          </div>
        </header>
        <div id="main" class="obsidian-dashboard-shell-scroll dash-main">
          {render_slot(@inner_block)}
        </div>
      </section>

      <div data-drawer-root class="dash-drawer" hidden>
        <div data-drawer-backdrop class="dash-drawer-backdrop"></div>
        <div
          data-drawer
          role="dialog"
          aria-modal="true"
          aria-label="Workspace"
          class="dash-drawer-panel"
        >
          <.sidebar
            list="drawer"
            workspace={@workspace}
            workspaces={@workspaces}
            tab={@tab}
            sections={@sections}
            active={@active}
            account={@current_user.email}
            close
          />
        </div>
      </div>
    </div>
    """
  end

  attr :list, :string, required: true
  attr :workspace, :map, required: true
  attr :workspaces, :list, required: true
  attr :tab, :atom, required: true
  attr :sections, :list, required: true
  attr :active, :string, required: true
  attr :account, :string, required: true
  attr :close, :boolean, default: false

  defp sidebar(assigns) do
    ~H"""
    <div class="dash-sidebar-body">
      <div class="dash-brand">
        <.workspace_switcher
          list={@list}
          workspace={@workspace}
          workspaces={@workspaces}
          tab={@tab}
        />
        <.button
          :if={@close}
          type="button"
          data-drawer-close
          variant="ghost"
          size="icon"
          aria-label="Close navigation"
        >
          <span class="dash-nav-icon" aria-hidden="true">
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </span>
        </.button>
      </div>

      <nav class="obsidian-dashboard-shell-scroll dash-nav-scroll" aria-label="Workspace">
        <div class="dash-nav-list" data-nav-list>
          <span id={"nav-#{@list}-hover"} data-hover phx-update="ignore" class="dash-float dash-hover">
          </span>
          <span id={"nav-#{@list}-pill"} data-pill phx-update="ignore" class="dash-float dash-pill">
          </span>
          <div
            :for={{section, index} <- Enum.with_index(@sections)}
            class={["dash-section", index < length(@sections) - 1 && "dash-section-divided"]}
          >
            <span :if={section.title} class="dash-section-title">{section.title}</span>
            <ul>
              <li :for={item <- section.items}>
                <.link
                  navigate={item.href}
                  data-nav-item
                  data-id={item.id}
                  data-active={if(@active == item.id, do: "true", else: "false")}
                  aria-current={@active == item.id && "page"}
                  class="dash-nav-item"
                >
                  <span class="dash-nav-icon" aria-hidden="true">
                    <.icon name={item.icon} class="h-4 w-4" />
                  </span>
                  <span class="dash-nav-label">{item.label}</span>
                </.link>
              </li>
            </ul>
          </div>
        </div>
      </nav>

      <div class="dash-footer">
        <p class="dash-footer-account">{@account}</p>
        <.link
          href={~p"/users/log_out"}
          method="delete"
          class="dash-btn dash-btn-ghost dash-btn-md dash-sign-out"
        >
          <span class="dash-nav-icon" aria-hidden="true">
            <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4" />
          </span>
          Sign out
        </.link>
      </div>
    </div>
    """
  end

  attr :list, :string, required: true
  attr :workspace, :map, required: true
  attr :workspaces, :list, required: true
  attr :tab, :atom, required: true

  defp workspace_switcher(assigns) do
    ~H"""
    <details id={"workspace-switcher-#{@list}"} class="dash-switcher">
      <summary class="dash-switcher-trigger" aria-label={"Switch workspace. Current: #{@workspace.name}"}>
        <img src={~p"/images/logo.png"} alt="" width="28" height="28" class="dash-logo dash-switcher-logo" />
        <span class="dash-switcher-name">{@workspace.name}</span>
        <span class="dash-switcher-caret" aria-hidden="true">
          <.icon name="caret-down" class="h-3.5 w-3.5" />
        </span>
      </summary>

      <div class="dash-switcher-menu" role="menu" aria-label="Workspaces">
        <ul class="dash-switcher-list">
          <li :for={ws <- @workspaces} role="none">
            <.link
              navigate={tab_path(ws.id, @tab)}
              role="menuitem"
              aria-current={ws.id == @workspace.id && "true"}
              class={[
                "dash-switcher-item",
                ws.id == @workspace.id && "dash-switcher-item-current"
              ]}
            >
              <span class="dash-switcher-avatar" aria-hidden="true">
                {ws.name |> String.first() |> String.upcase()}
              </span>
              <span class="dash-switcher-item-name">{ws.name}</span>
              <span :if={ws.id == @workspace.id} class="dash-switcher-check" aria-hidden="true">
                <.icon name="check" class="h-4 w-4" />
              </span>
            </.link>
          </li>
        </ul>

        <div class="dash-switcher-footer">
          <.link navigate={~p"/workspaces/new"} class="dash-switcher-action" role="menuitem">
            <.icon name="plus" class="h-4 w-4" /> New workspace
          </.link>
        </div>
      </div>
    </details>
    """
  end

  defp tab_path(workspace_id, :business), do: ~p"/workspaces/#{workspace_id}"
  defp tab_path(workspace_id, :products), do: ~p"/workspaces/#{workspace_id}/products"
  defp tab_path(workspace_id, :cta), do: ~p"/workspaces/#{workspace_id}/cta"
  defp tab_path(workspace_id, :meta), do: ~p"/workspaces/#{workspace_id}/connection"
  defp tab_path(workspace_id, :playground), do: ~p"/workspaces/#{workspace_id}/playground"
  defp tab_path(workspace_id, :analytics), do: ~p"/workspaces/#{workspace_id}/analytics"
  defp tab_path(workspace_id, _), do: ~p"/workspaces/#{workspace_id}"

  defp nav_sections(workspace_id) do
    [
      %{
        title: "Setup",
        items: [
          %{
            id: "business",
            href: ~p"/workspaces/#{workspace_id}",
            icon: "hero-building-storefront",
            label: "Business"
          },
          %{
            id: "products",
            href: ~p"/workspaces/#{workspace_id}/products",
            icon: "hero-squares-2x2",
            label: "Products"
          },
          %{
            id: "cta",
            href: ~p"/workspaces/#{workspace_id}/cta",
            icon: "hero-cursor-arrow-rays",
            label: "CTA Rules"
          },
          %{
            id: "meta",
            href: ~p"/workspaces/#{workspace_id}/connection",
            icon: "hero-signal",
            label: "Meta"
          }
        ]
      },
      %{
        title: "Test",
        items: [
          %{
            id: "playground",
            href: ~p"/workspaces/#{workspace_id}/playground",
            icon: "hero-chat-bubble-left-right",
            label: "Playground"
          }
        ]
      },
      %{
        title: "Insights",
        items: [
          %{
            id: "analytics",
            href: ~p"/workspaces/#{workspace_id}/analytics",
            icon: "hero-chart-bar",
            label: "Analytics"
          }
        ]
      }
    ]
  end
end
