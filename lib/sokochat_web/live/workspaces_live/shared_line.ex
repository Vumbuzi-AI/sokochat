defmodule SokochatWeb.WorkspacesLive.SharedLine do
  use SokochatWeb, :live_view

  alias Ecto.Changeset
  alias Sokochat.Meta

  @impl true
  def mount(_params, _session, socket) do
    account_id = socket.assigns.current_user.id
    shared_line = Meta.get_shared_line_or_new(account_id)
    shops = if shared_line.id, do: Meta.list_shared_line_shops(shared_line.id), else: []

    {:ok,
     socket
     |> assign(:page_title, "Shared WhatsApp line")
     |> assign(:shared_line, shared_line)
     |> assign(:shops, shops)
     |> assign_form(Meta.change_shared_line(shared_line))}
  end

  @impl true
  def handle_event("validate", %{"shared_line" => params}, socket) do
    changeset =
      socket.assigns.shared_line
      |> Meta.change_shared_line(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"shared_line" => params}, socket) do
    case Meta.upsert_shared_line(socket.assigns.current_user.id, params) do
      {:ok, shared_line} ->
        shops = Meta.list_shared_line_shops(shared_line.id)

        {:noreply,
         socket
         |> assign(:shared_line, shared_line)
         |> assign(:shops, shops)
         |> assign_form(Meta.change_shared_line(shared_line))
         |> put_flash(:info, "Shared line saved. Point Meta's webhook at the URL below.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp assign_form(socket, %Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :shared_line))
  end

  defp persisted?(%{id: id}) when not is_nil(id), do: true
  defp persisted?(_), do: false

  defp webhook_url(socket), do: url(socket, ~p"/webhooks/whatsapp")

  defp status_tone("active"), do: "success"
  defp status_tone("error"), do: "danger"
  defp status_tone(_), do: "waiting"

  defp status_label("active"), do: "Active"
  defp status_label("error"), do: "Error"
  defp status_label(_), do: "Pending"

  defp verified_label(nil), do: "Not verified yet"
  defp verified_label(%DateTime{} = at), do: Calendar.strftime(at, "%d %b %Y, %H:%M UTC")

  @impl true
  def render(assigns) do
    ~H"""
    <.stage_page title="Shared WhatsApp line" current_user={@current_user}>
      <div class="soko-panel mx-auto max-w-[960px] p-6">
        <.section
          title="Shared WhatsApp line"
          text="One WhatsApp number for every shop on this account. A shop code in the first message, or a shop picker, decides which shop answers."
        >
          <div class="flex items-center gap-2 text-sm text-soko-ink-2">
            Status
            <.badge tone={status_tone(@shared_line.status)}>
              {status_label(@shared_line.status)}
            </.badge>
          </div>
          <.banner :if={@shared_line.last_error} tone="danger">{@shared_line.last_error}</.banner>
          <.simple_form for={@form} phx-change="validate" phx-submit="save">
            <div class="soko-field-row">
              <.input field={@form[:phone_number_id]} label="Phone Number ID" required />
              <.input field={@form[:waba_id]} label="WhatsApp Business Account ID" required />
            </div>
            <.input
              field={@form[:display_phone]}
              label="Display phone"
              placeholder="254712345678"
              hint="Digits only, with the country code. Used in each shop's wa.me link."
              required
            />
            <.input
              field={@form[:access_token]}
              type="password"
              label="Access token"
              hint="Saving sets the status back to pending until the webhook is verified again."
              required
              autocomplete="off"
            />
            <:actions>
              <.button size="sm">Save shared line</.button>
            </:actions>
          </.simple_form>
        </.section>

        <.section
          :if={persisted?(@shared_line)}
          title="Webhook"
          text="Point your Meta app webhook at this one URL, then subscribe to messages."
        >
          <.copy_field id="shared-webhook-url" label="Callback URL" value={webhook_url(@socket)} />
          <.copy_field
            id="shared-verify-token"
            label="Verify token"
            value={@shared_line.verify_token}
          />
          <div class="flex flex-col gap-2 rounded-[12px] border border-soko-line bg-soko-white p-4">
            <.checklist_item done={true} label="Details saved" />
            <.checklist_item
              done={not is_nil(@shared_line.webhook_verified_at)}
              label={"Webhook verified, #{verified_label(@shared_line.webhook_verified_at)}"}
            />
            <.checklist_item
              done={@shared_line.status == "active"}
              label="Shared line active and ready for messages"
            />
          </div>
        </.section>

        <.section
          :if={persisted?(@shared_line)}
          title="Shops on this line"
          text="Each shop gets a wa.me link with its shop code filled in."
        >
          <p :if={@shops == []} class="text-sm text-soko-ink-2">No shops have joined yet.</p>
          <div
            :if={@shops != []}
            class="overflow-hidden rounded-[12px] border border-soko-line bg-soko-white"
          >
            <.link
              :for={shop <- @shops}
              navigate={~p"/workspaces/#{shop.id}/connection"}
              class="flex items-center gap-3 border-b border-soko-divider px-4 py-3 last:border-b-0 hover:bg-soko-hover"
            >
              <.avatar seed={shop.id} size="sm" />
              <span class="flex-1 text-sm font-medium">{shop.name}</span>
              <span class="font-mono text-xs text-soko-ink-3">[shop:{shop.shop_code}]</span>
              <.icon name="caret-right" class="h-4 w-4 text-soko-ink-3" />
            </.link>
          </div>
        </.section>
      </div>
    </.stage_page>
    """
  end
end
