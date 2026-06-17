defmodule SokochatWeb.WorkspacesLive.Meta do
  use SokochatWeb, :live_view

  alias Ecto.Changeset
  alias Sokochat.Catalogs
  alias Sokochat.CTARules
  alias Sokochat.Endpoints
  alias Sokochat.Meta
  alias Sokochat.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meta Connection")
     |> assign(:workspace, nil)
     |> assign(:connection, nil)
     |> assign(:data_ingestion_configured, false)
     |> assign(:cta_rules_configured, false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        connection = Meta.get_connection_or_new(workspace.id)
        endpoint = Endpoints.get_endpoint(workspace.id)
        catalog = Catalogs.get_catalog(workspace.id)
        cta_rules = CTARules.list_cta_rules(workspace.id)

        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:connection, connection)
         |> assign(:data_ingestion_configured, data_ingestion_configured?(endpoint, catalog))
         |> assign(:cta_rules_configured, cta_rules != [])
         |> assign_form(Meta.change_connection(connection))}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  @impl true
  def handle_event("validate", %{"connection" => params}, socket) do
    changeset =
      socket.assigns.connection
      |> Meta.change_connection(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"connection" => params}, socket) do
    case Meta.upsert_connection(socket.assigns.workspace.id, params) do
      {:ok, connection} ->
        {:noreply,
         socket
         |> assign(:connection, connection)
         |> assign_form(Meta.change_connection(connection))
         |> put_flash(:info, "Meta credentials saved. Now configure the webhook below.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp assign_form(socket, %Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :connection))
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp persisted?(%{id: id}) when not is_nil(id), do: true
  defp persisted?(_), do: false

  defp webhook_url(socket, slug), do: url(socket, ~p"/webhooks/whatsapp/#{slug}")

  defp data_ingestion_configured?(endpoint, catalog) do
    endpoint_configured?(endpoint) or catalog_configured?(catalog)
  end

  defp endpoint_configured?(%{url: url}) when is_binary(url), do: String.trim(url) != ""
  defp endpoint_configured?(_), do: false

  defp catalog_configured?(%{id: id}) when not is_nil(id), do: true
  defp catalog_configured?(_), do: false

  defp status_badge_class("active"), do: "border-[#B7EBCF] bg-[#E8FFF3] text-primary"
  defp status_badge_class("error"), do: "border-[#FFCDD2] bg-danger-bg text-danger"
  defp status_badge_class(_), do: "border-n300 bg-n200 text-n400"

  defp status_label("active"), do: "Active"
  defp status_label("error"), do: "Error"
  defp status_label(_), do: "Pending"

  defp verified_label(nil), do: "Not verified yet"
  defp verified_label(%DateTime{} = at), do: Calendar.strftime(at, "%d %b %Y, %H:%M UTC")

  defp meta_alerts(connection, data_ingestion_configured, cta_rules_configured) do
    []
    |> maybe_add_credentials_alert(connection)
    |> maybe_add_webhook_alert(connection)
    |> maybe_add_workspace_alert(data_ingestion_configured, cta_rules_configured)
    |> Enum.reverse()
  end

  defp maybe_add_credentials_alert(alerts, %{id: id}) when not is_nil(id), do: alerts

  defp maybe_add_credentials_alert(alerts, _connection) do
    [
      %{
        tone: :warning,
        title: "Start in Meta → WhatsApp → API Setup",
        body:
          "Copy your Phone Number ID, WhatsApp Business Account ID, and a long-lived access token into this form first. Saving them unlocks the webhook values below."
      }
      | alerts
    ]
  end

  defp maybe_add_webhook_alert(alerts, %{id: id, webhook_verified_at: nil}) when not is_nil(id) do
    [
      %{
        tone: :warning,
        title: "Webhook still needs verification",
        body:
          "Use the Callback URL and Verify token below in Meta → WhatsApp → Configuration, then subscribe to the messages field so inbound messages reach this workspace."
      }
      | alerts
    ]
  end

  defp maybe_add_webhook_alert(alerts, _connection), do: alerts

  defp maybe_add_workspace_alert(alerts, true, true), do: alerts

  defp maybe_add_workspace_alert(alerts, data_ingestion_configured, cta_rules_configured) do
    missing =
      []
      |> maybe_add_missing("Data Ingestion", data_ingestion_configured)
      |> maybe_add_missing("CTA Rules", cta_rules_configured)
      |> Enum.join(" and ")

    [
      %{
        tone: :info,
        title: "Finish the workspace before going live",
        body:
          "#{missing} #{if String.ends_with?(missing, "Rules"), do: "are", else: "is"} still missing. Configure them so WhatsApp replies can use real business data and rich actions."
      }
      | alerts
    ]
  end

  defp maybe_add_missing(items, _label, true), do: items
  defp maybe_add_missing(items, label, false), do: items ++ [label]

  defp alert_classes(:warning),
    do: "border-[#FFD9A0] border-l-[#C77700] bg-[#FFF8ED] text-[#7A4A00]"

  defp alert_classes(:info),
    do: "border-[#BFD7FF] border-l-[#2F6FED] bg-[#F4F8FF] text-[#23448E]"

  defp alert_classes(:success),
    do: "border-[#B7EBCF] border-l-primary bg-[#E8FFF3] text-primary"

  defp alert_icon(:warning), do: "hero-exclamation-triangle-mini"
  defp alert_icon(:info), do: "hero-information-circle-mini"
  defp alert_icon(:success), do: "hero-check-circle-mini"

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@workspace} class="mx-auto max-w-3xl space-y-6">
      <nav class="flex items-center gap-1.5 text-[13px] text-n500">
        <.link navigate={~p"/workspaces"} class="transition hover:text-n400">Workspaces</.link>
        <span>/</span>
        <.link navigate={~p"/workspaces/#{@workspace.id}"} class="transition hover:text-n400">
          {@workspace.name}
        </.link>
        <span>/</span>
        <span class="text-n400">Meta Connection</span>
      </nav>

      <div class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]">
        <div class="space-y-1.5 border-b border-n300 px-8 py-6">
          <h1 class="text-[22px] font-bold tracking-tight text-n900">Meta Connection</h1>
          <p class="max-w-2xl text-sm leading-6 text-n400">
            Connect this workspace to the WhatsApp Business Platform. Save your Cloud API
            credentials, then point Meta's webhook at the URL below to go live.
          </p>
        </div>

        <div class="space-y-6 px-8 py-6">
          <div
            :for={
              alert <- meta_alerts(@connection, @data_ingestion_configured, @cta_rules_configured)
            }
            role="alert"
            class={[
              "flex items-start gap-2 rounded-lg border border-l-4 px-4 py-3 text-[13px]",
              alert_classes(alert.tone)
            ]}
          >
            <.icon name={alert_icon(alert.tone)} class="mt-0.5 h-4 w-4 flex-none" />
            <div class="space-y-1">
              <p class="font-semibold">{alert.title}</p>
              <p>{alert.body}</p>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-n400">Status</span>
            <span class={[
              "inline-flex items-center rounded-full border px-3 py-0.5 text-xs font-semibold",
              status_badge_class(@connection.status)
            ]}>
              {status_label(@connection.status)}
            </span>
          </div>

          <div
            :if={@connection.last_error}
            role="alert"
            class="flex items-start gap-2 rounded-lg border border-[#FFCDD2] border-l-4 border-l-danger bg-danger-bg px-4 py-3 text-[13px] text-n400"
          >
            <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-4 w-4 flex-none text-danger" />
            <span>{@connection.last_error}</span>
          </div>

          <.simple_form for={@form} phx-change="validate" phx-submit="save">
            <.input field={@form[:phone_number_id]} label="Phone Number ID" required />
            <.input field={@form[:waba_id]} label="WhatsApp Business Account ID" required />
            <.input
              field={@form[:access_token]}
              type="password"
              label="Access Token"
              required
              autocomplete="off"
            />
            <p class="-mt-3 text-[13px] text-n400">
              The access token is encrypted at rest. Saving new credentials resets the
              connection to <span class="font-medium">pending</span> until the webhook is re-verified.
            </p>

            <:actions>
              <.link
                navigate={~p"/workspaces/#{@workspace.id}"}
                class="mr-auto text-sm font-medium text-n400 transition hover:text-n900"
              >
                Back to dashboard
              </.link>
              <.button>Save credentials</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>

      <div
        :if={persisted?(@connection)}
        class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]"
      >
        <div class="space-y-1.5 border-b border-n300 px-8 py-6">
          <h2 class="text-[17px] font-bold tracking-tight text-n900">Webhook setup</h2>
          <p class="text-sm leading-6 text-n400">
            In your Meta app, open WhatsApp → Configuration → Webhooks and paste these values,
            then subscribe to the <span class="font-medium">messages</span> field.
          </p>
        </div>

        <div class="space-y-5 px-8 py-6">
          <.copy_field
            id="webhook-url"
            label="Callback URL"
            value={webhook_url(@socket, @workspace.slug)}
          />
          <.copy_field id="verify-token" label="Verify token" value={@connection.verify_token} />
        </div>
      </div>

      <div
        :if={persisted?(@connection)}
        class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]"
      >
        <div class="space-y-1.5 border-b border-n300 px-8 py-6">
          <h2 class="text-[17px] font-bold tracking-tight text-n900">Setup checklist</h2>
        </div>
        <div class="space-y-3 px-8 py-6 text-sm">
          <.checklist_item done={true} label="Credentials saved" />
          <.checklist_item
            done={not is_nil(@connection.webhook_verified_at)}
            label={"Webhook verified — #{verified_label(@connection.webhook_verified_at)}"}
          />
          <.checklist_item
            done={@connection.status == "active"}
            label="Connection active and ready to receive messages"
          />
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
