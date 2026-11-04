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

  defp status_badge_class("active"), do: "border-[#B7EBCF] bg-[#E8FFF3] text-primary"
  defp status_badge_class("error"), do: "border-[#FFCDD2] bg-danger-bg text-danger"
  defp status_badge_class(_), do: "border-n300 bg-n200 text-n400"

  defp status_label("active"), do: "Active"
  defp status_label("error"), do: "Error"
  defp status_label(_), do: "Pending"

  defp verified_label(nil), do: "Not verified yet"
  defp verified_label(%DateTime{} = at), do: Calendar.strftime(at, "%d %b %Y, %H:%M UTC")

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-3xl space-y-6">
      <nav class="flex items-center gap-1.5 text-[13px] text-n500">
        <.link navigate={~p"/workspaces"} class="transition hover:text-n400">Workspaces</.link>
        <span>/</span>
        <span class="text-n400">Shared WhatsApp line</span>
      </nav>

      <div class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]">
        <div class="space-y-1.5 border-b border-n300 px-8 py-6">
          <h1 class="text-[22px] font-bold tracking-tight text-n900">Shared WhatsApp line</h1>
          <p class="max-w-2xl text-sm leading-6 text-n400">
            One Cloud API number for every shop under this account. Buyers message the same
            number; a shop code in the first message (or a shop picker) chooses which workspace
            answers.
          </p>
        </div>

        <div class="space-y-6 px-8 py-6">
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-n400">Status</span>
            <span class={[
              "inline-flex items-center rounded-full border px-3 py-0.5 text-xs font-semibold",
              status_badge_class(@shared_line.status)
            ]}>
              {status_label(@shared_line.status)}
            </span>
          </div>

          <div
            :if={@shared_line.last_error}
            role="alert"
            class="flex items-start gap-2 rounded-lg border border-[#FFCDD2] border-l-4 border-l-danger bg-danger-bg px-4 py-3 text-[13px] text-n400"
          >
            <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-4 w-4 flex-none text-danger" />
            <span>{@shared_line.last_error}</span>
          </div>

          <.simple_form for={@form} phx-change="validate" phx-submit="save">
            <.input field={@form[:phone_number_id]} label="Phone Number ID" required />
            <.input field={@form[:waba_id]} label="WhatsApp Business Account ID" required />
            <.input
              field={@form[:display_phone]}
              label="Display phone (E.164 digits)"
              placeholder="254700123456"
              required
            />
            <.input
              field={@form[:access_token]}
              type="password"
              label="Access Token"
              required
              autocomplete="off"
            />
            <p class="-mt-3 text-[13px] text-n400">
              Display phone is used in shop <span class="font-medium">wa.me</span>
              links. Saving credentials resets status to pending until the webhook is re-verified.
            </p>

            <:actions>
              <.button>Save shared line</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>

      <div
        :if={persisted?(@shared_line)}
        class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]"
      >
        <div class="space-y-1.5 border-b border-n300 px-8 py-6">
          <h2 class="text-[17px] font-bold tracking-tight text-n900">Webhook setup</h2>
          <p class="text-sm leading-6 text-n400">
            Point Meta's app webhook at this single URL (not a per-workspace slug), then
            subscribe to the <span class="font-medium">messages</span> field.
          </p>
        </div>

        <div class="space-y-5 px-8 py-6">
          <.copy_field id="shared-webhook-url" label="Callback URL" value={webhook_url(@socket)} />
          <.copy_field
            id="shared-verify-token"
            label="Verify token"
            value={@shared_line.verify_token}
          />
        </div>
      </div>

      <div
        :if={persisted?(@shared_line)}
        class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]"
      >
        <div class="space-y-1.5 border-b border-n300 px-8 py-6">
          <h2 class="text-[17px] font-bold tracking-tight text-n900">Setup checklist</h2>
        </div>
        <div class="space-y-3 px-8 py-6 text-sm">
          <.checklist_item done={true} label="Credentials saved" />
          <.checklist_item
            done={not is_nil(@shared_line.webhook_verified_at)}
            label={"Webhook verified — #{verified_label(@shared_line.webhook_verified_at)}"}
          />
          <.checklist_item
            done={@shared_line.status == "active"}
            label="Shared line active and ready to receive messages"
          />
        </div>
      </div>

      <div
        :if={persisted?(@shared_line)}
        class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]"
      >
        <div class="space-y-1.5 border-b border-n300 px-8 py-6">
          <h2 class="text-[17px] font-bold tracking-tight text-n900">Shops on this line</h2>
          <p class="text-sm leading-6 text-n400">
            Join a workspace from its Meta connection page. Each shop gets a
            <span class="font-medium">wa.me</span> link with a prefilled shop code.
          </p>
        </div>
        <div class="px-8 py-6">
          <p :if={@shops == []} class="text-sm text-n400">No shops have joined yet.</p>
          <ul :if={@shops != []} class="space-y-3 text-sm">
            <li :for={shop <- @shops} class="flex flex-col gap-1 rounded-lg border border-n300 p-3">
              <div class="flex items-center justify-between gap-3">
                <span class="font-medium text-n900">{shop.name}</span>
                <span class="font-mono text-xs text-n400">[shop:{shop.shop_code}]</span>
              </div>
              <.link
                navigate={~p"/workspaces/#{shop.id}/connection"}
                class="text-xs font-medium text-primary hover:underline"
              >
                Open workspace connection
              </.link>
            </li>
          </ul>
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  defp copy_field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-n900">{@label}</label>
      <div class="mt-1.5 flex items-center gap-2">
        <input
          id={@id}
          type="text"
          readonly
          value={@value}
          class="w-full rounded-lg border border-n300 bg-n200 px-3 py-2 font-mono text-[13px] text-n900"
        />
        <button
          id={"copy-#{@id}"}
          type="button"
          phx-hook="ClipboardCopy"
          data-copy={@value}
          class="inline-flex h-9 flex-none items-center gap-1.5 rounded-lg border border-n300 bg-n50 px-3 text-sm font-medium text-n900 transition hover:bg-n200"
          title="Copy to clipboard"
        >
          <.icon name="hero-document-duplicate-mini" class="h-4 w-4" /> Copy
        </button>
      </div>
    </div>
    """
  end

  attr :done, :boolean, required: true
  attr :label, :string, required: true

  defp checklist_item(assigns) do
    ~H"""
    <div class="flex items-center gap-2.5">
      <.icon :if={@done} name="hero-check-circle-mini" class="h-5 w-5 flex-none text-primary" />
      <.icon :if={not @done} name="hero-minus-circle-mini" class="h-5 w-5 flex-none text-n500" />
      <span class={if @done, do: "text-n900", else: "text-n400"}>{@label}</span>
    </div>
    """
  end
end
