defmodule SokochatWeb.WorkspacesLive.Inbox do
  use SokochatWeb, :live_view
  import SokochatWeb.WorkspaceShell
  alias Sokochat.{Marketplace, Workspaces}
  alias Sokochat.Marketplace.{Chat, Orders}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    workspace = Workspaces.get_workspace!(id, socket.assigns.current_user.id)

    if connected?(socket),
      do: Phoenix.PubSub.subscribe(Sokochat.PubSub, Orders.topic(workspace.id))

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:workspaces, Workspaces.list_workspaces(socket.assigns.current_user.id))
     |> assign(:page_title, "Inbox")
     |> assign(:selected_id, nil)
     |> reload(), layout: false}
  end

  @impl true
  def handle_event("select_order", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:selected_id, Marketplace.parse_id(id)) |> reload()}
  end

  def handle_event("mark_contacted", %{"id" => id}, socket) do
    case Orders.mark_contacted(socket.assigns.workspace.id, id) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Request marked as contacted.") |> reload()}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to update this request. Refresh and try again.")
         |> reload()}
    end
  end

  @impl true
  def handle_info(:orders_changed, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    orders = Orders.list(socket.assigns.workspace.id)
    selected = Enum.find(orders, &(&1.id == socket.assigns.selected_id)) || List.first(orders)

    socket
    |> assign(:orders, orders)
    |> assign(:selected, selected)
    |> assign(:selected_id, selected && selected.id)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.shell
      workspace={@workspace}
      workspaces={@workspaces}
      current_user={@current_user}
      tab={:inbox}
      title="Inbox"
      subtitle="Order requests"
      flash={@flash}
      flush
    >
      <div :if={@orders == []} class="soko-inbox-empty">
        <.empty
          title="No order requests yet"
          text="Requests for your products will appear here when a buyer confirms them on Sokochat."
        >
          <:actions>
            <.button navigate={~p"/workspaces/#{@workspace.id}/products"} tone="secondary">
              View products
            </.button>
          </:actions>
        </.empty>
      </div>
      <div :if={@orders != []} class="soko-inbox">
        <aside class="soko-inbox-list" aria-label="Order requests">
          <h2>Order requests</h2>
          <button
            :for={order <- @orders}
            type="button"
            phx-click="select_order"
            phx-value-id={order.id}
            class={["soko-inbox-row", order.id == @selected_id && "is-selected"]}
            aria-pressed={order.id == @selected_id}
          >
            <.avatar seed={order.id} />
            <span>{order.phone_number}</span>
            <small>{order.product["title"]} · 1 item</small>
            <.badge tone={if(order.status == "requested", do: "waiting", else: "neutral")}>
              {if(order.status == "requested", do: "New request", else: "Contacted")}
            </.badge>
          </button>
        </aside>
        <article :if={@selected} class="soko-inbox-detail" aria-live="polite">
          <h2>Order request #{@selected.id}</h2>
          <p class="soko-inbox-source">From Sokochat · For {@workspace.name}</p>
          <div class="soko-inbox-product">
            <img
              :if={@selected.product["image_url"]}
              src={@selected.product["image_url"]}
              alt={@selected.product["title"]}
            />
            <div>
              <h3>{@selected.product["title"]}</h3>
              <p>1 item · {Chat.price_text(@selected.product)}</p>
              <small>Size and availability to confirm with buyer</small>
            </div>
          </div>
          <div class="soko-inbox-buyer">
            <small>Buyer</small>
            <p>{@selected.phone_number}</p>
          </div>
          <.banner tone="info">
            Contact the buyer to confirm size, stock, delivery and payment. This request has not been paid.
          </.banner>
          <div class="soko-inbox-action">
            <.button
              :if={@selected.status == "requested"}
              phx-click="mark_contacted"
              phx-value-id={@selected.id}
              phx-disable-with="Saving…"
            >
              Mark as contacted
            </.button>
            <.badge :if={@selected.status == "contacted"} tone="neutral">Contacted</.badge>
          </div>
          <p class="soko-inbox-privacy">Only requests for your products appear here.</p>
        </article>
      </div>
    </.shell>
    """
  end
end
