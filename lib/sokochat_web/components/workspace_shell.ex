defmodule SokochatWeb.WorkspaceShell do
  @moduledoc """
  The desk: Soko Sidebar, Soko Page Header and the content panel.
  """
  use SokochatWeb, :html

  attr :workspace, :map, required: true
  attr :workspaces, :list, default: []
  attr :current_user, :map, required: true
  attr :tab, :atom, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :flush, :boolean, default: false, doc: "drop the panel padding for full-bleed content"
  attr :inbox_counts, :map, default: %{}, doc: "pending order requests by workspace id"
  attr :flash, :map, default: %{}
  slot :actions
  slot :inner_block, required: true

  def shell(assigns) do
    assigns = assign(assigns, :sections, nav_sections(assigns.workspace.id))

    ~H"""
    <div
      id={"workspace-#{@workspace.id}"}
      phx-hook="DashboardShell"
      data-workspace-id={@workspace.id}
      class="soko-desk"
    >
      <.flash_group flash={@flash} />

      <.sidebar
        list="dock"
        workspace={@workspace}
        workspaces={@workspaces}
        tab={@tab}
        sections={@sections}
        account={@current_user.email}
        inbox_counts={@inbox_counts}
      />

      <section data-panel class="soko-desk-main" aria-labelledby="workspace-title">
        <header class="soko-page-header">
          <div class="soko-page-titles">
            <.icon_button
              icon="list"
              class="soko-desk-menu"
              data-menu
              aria-label="Open navigation"
              aria-expanded="false"
            />
            <h1 id="workspace-title" class="soko-page-title">{@title}</h1>
            <span :if={@subtitle} class="soko-page-subtitle">{@subtitle}</span>
          </div>
          <div :if={@actions != []} class="soko-page-actions">{render_slot(@actions)}</div>
        </header>
        <div id="main" class="soko-desk-panel" data-flush={@flush}>
          {render_slot(@inner_block)}
        </div>
      </section>

      <.confirm_dialog
        id="logout-dialog"
        title="Log out of Sokochat?"
        text="You'll need your email and password to get back to your desk."
      >
        <:actions>
          <.button href={~p"/users/log_out"} method="delete" tone="danger">
            <.icon name="sign-out" /> Log out
          </.button>
        </:actions>
      </.confirm_dialog>

      <div data-drawer-root class="soko-drawer" hidden>
        <div data-drawer-backdrop class="soko-drawer-backdrop"></div>
        <div
          id={"workspace-drawer-#{@workspace.id}"}
          data-drawer
          role="dialog"
          aria-modal="true"
          aria-label="Navigation"
          class="soko-drawer-panel"
        >
          <.sidebar
            list="drawer"
            workspace={@workspace}
            workspaces={@workspaces}
            tab={@tab}
            sections={@sections}
            account={@current_user.email}
            inbox_counts={@inbox_counts}
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
  attr :account, :string, required: true
  attr :inbox_counts, :map, default: %{}
  attr :close, :boolean, default: false

  defp sidebar(assigns) do
    ~H"""
    <aside class="soko-sidebar">
      <div class="soko-sidebar-top">
        <.switcher
          list={@list}
          workspace={@workspace}
          workspaces={@workspaces}
          tab={@tab}
          inbox_counts={@inbox_counts}
        />
        <.icon_button :if={@close} icon="x" data-drawer-close aria-label="Close navigation" />
      </div>

      <nav class="soko-sidebar-nav" aria-label="Shop">
        <%= for section <- @sections do %>
          <span class="soko-nav-group">{section.title}</span>
          <.link
            :for={item <- section.items}
            navigate={item.href}
            class="soko-nav-item"
            data-nav-item
            data-id={item.id}
            data-active={to_string(item.id == @tab)}
            aria-current={item.id == @tab && "page"}
          >
            <span class="soko-nav-icon" aria-hidden="true">
              <.icon name={item.icon} weight={if item.id == @tab, do: "fill", else: "regular"} />
            </span>
            <span class="soko-nav-label">{item.label}</span>
            <.notice_pill :if={item.id == :inbox} count={notice_count(@inbox_counts, @workspace.id)} />
          </.link>
        <% end %>
      </nav>

      <div class="soko-sidebar-account">
        <.avatar seed={@account} size="sm" />
        <.link navigate={~p"/users/settings"} class="soko-sidebar-email" title="Account settings">
          {@account}
        </.link>
        <.icon_button
          icon="sign-out"
          tone="danger"
          data-dialog-open="logout-dialog"
          aria-haspopup="dialog"
          aria-label="Log out"
          title="Log out"
        />
      </div>
    </aside>
    """
  end

  attr :list, :string, required: true
  attr :workspace, :map, required: true
  attr :workspaces, :list, required: true
  attr :tab, :atom, required: true
  attr :inbox_counts, :map, default: %{}

  defp switcher(assigns) do
    assigns = assign(assigns, :others, others_count(assigns.inbox_counts, assigns.workspace.id))

    ~H"""
    <details id={"workspace-switcher-#{@list}"} class="soko-switcher" data-switcher>
      <summary aria-label={switcher_label(@workspace.name, @others)}>
        <img src={~p"/images/logo.png"} alt="" width="28" height="28" class="soko-mark" />
        <span class="soko-switcher-name">{@workspace.name}</span>
        <.notice_pill count={@others} />
        <span class="soko-switcher-caret" aria-hidden="true">
          <.icon name="caret-down" class="h-3.5 w-3.5" />
        </span>
      </summary>

      <div class="soko-switcher-menu" role="menu" aria-label="Shops">
        <.link
          :for={ws <- @workspaces}
          navigate={tab_path(ws.id, @tab)}
          role="menuitem"
          aria-current={ws.id == @workspace.id && "true"}
          class="soko-switcher-item"
        >
          <.avatar seed={ws.id} size="sm" />
          <span class="min-w-0 flex-1 truncate">{ws.name}</span>
          <.notice_pill :if={ws.id != @workspace.id} count={notice_count(@inbox_counts, ws.id)} />
          <.icon :if={ws.id == @workspace.id} name="check" />
        </.link>
        <div class="soko-switcher-divider"></div>
        <.link navigate={~p"/workspaces/new"} class="soko-switcher-item" role="menuitem">
          <.icon name="plus" /> New workspace
        </.link>
        <.link
          navigate={~p"/workspaces/#{@workspace.id}/edit"}
          class="soko-switcher-item"
          role="menuitem"
        >
          <.icon name="pencil-simple" /> Edit workspace
        </.link>
      </div>
    </details>
    """
  end

  attr :count, :integer, required: true

  defp notice_pill(assigns) do
    ~H"""
    <span
      :if={@count > 0}
      class="soko-nav-count"
      data-tone="alert"
      aria-label={"#{@count} to address"}
    >
      {if @count > 99, do: "99+", else: @count}
    </span>
    """
  end

  defp notice_count(counts, id), do: Map.get(counts || %{}, id, 0)

  defp others_count(counts, current_id) do
    (counts || %{})
    |> Map.drop([current_id])
    |> Map.values()
    |> Enum.sum()
  end

  defp switcher_label(name, 0), do: "Switch shop. Current: #{name}"

  defp switcher_label(name, count),
    do: "Switch shop. Current: #{name}. #{count} to address in other shops."

  defp tab_path(workspace_id, :products), do: ~p"/workspaces/#{workspace_id}/products"
  defp tab_path(workspace_id, :playground), do: ~p"/workspaces/#{workspace_id}/playground"
  defp tab_path(workspace_id, :analytics), do: ~p"/workspaces/#{workspace_id}/analytics"
  defp tab_path(workspace_id, :inbox), do: ~p"/workspaces/#{workspace_id}/inbox"
  defp tab_path(workspace_id, _), do: ~p"/workspaces/#{workspace_id}"

  defp nav_sections(workspace_id) do
    [
      %{
        title: "Sell",
        items: [
          %{
            id: :products,
            href: ~p"/workspaces/#{workspace_id}/products",
            icon: "package",
            label: "Products"
          },
          %{
            id: :inbox,
            href: ~p"/workspaces/#{workspace_id}/inbox",
            icon: "chat-circle",
            label: "Inbox"
          },
          %{
            id: :business,
            href: ~p"/workspaces/#{workspace_id}",
            icon: "storefront",
            label: "Business"
          },
          %{
            id: :analytics,
            href: ~p"/workspaces/#{workspace_id}/analytics",
            icon: "chart-bar",
            label: "Analytics"
          }
        ]
      },
      %{
        title: "Try",
        items: [
          %{
            id: :playground,
            href: ~p"/workspaces/#{workspace_id}/playground",
            icon: "device-mobile",
            label: "Playground"
          }
        ]
      }
    ]
  end
end
