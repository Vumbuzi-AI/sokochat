defmodule SokochatWeb.WorkspacesLive.Setup do
  @moduledoc """
  Unified "Live-Build" workspace setup experience: a three-step stepper
  (Products → CTA Rules → Meta) on the left, with a persistent WhatsApp
  playground simulator docked on the right that exercises the live workspace
  context as each step is configured.
  """
  use SokochatWeb, :live_view

  import SokochatWeb.PlaygroundChat

  alias Ecto.Changeset
  alias Sokochat.AI.CtaRecommender
  alias Sokochat.Catalogs
  alias Sokochat.Catalogs.{Catalog, Field, Item}
  alias Sokochat.Conversations
  alias Sokochat.Conversations.Dispatcher
  alias Sokochat.Conversations.Message
  alias Sokochat.CTARules
  alias Sokochat.CTARules.CTARule
  alias Sokochat.CTARules.RuleForm
  alias Sokochat.Endpoints
  alias Sokochat.Meta
  alias Sokochat.Workspaces

  @steps [:business, :products, :cta, :meta]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workspace setup")
     |> assign(:workspace, nil)
     |> assign(:active_step, :business)
     |> assign(:active_tab, "manual")
     |> assign(:active_modal, nil)
     |> assign(:lang, "EN")
     # products / data ingestion
     |> assign(:endpoint, nil)
     |> assign(:catalog, nil)
     |> assign(:selected_item, nil)
     |> assign(:selected_field, nil)
     |> assign(:item_values, %{})
     |> assign(:preview_json, nil)
     |> assign(:preview_label, nil)
     |> assign(:test_error, nil)
     # cta rules
     |> assign(:cta_rules, [])
     |> assign(:editing_rule, nil)
     |> assign(:cta_suggestions, [])
     |> assign(:recommending, false)
     |> assign(:recommend_ref, nil)
     # meta
     |> assign(:connection, nil)
     |> assign(:data_ingestion_configured, false)
     |> assign(:cta_rules_configured, false)
     |> assign(:meta_configured, false)
     # playground
     |> assign(:conversation, nil)
     |> assign(:phone_number, nil)
     |> assign(:subscribed_workspace_id, nil)
     |> assign(:message_ids, MapSet.new())
     |> assign(:pending_user_message, nil)
     |> assign(:assistant_pending, false)
     |> assign(:active_dispatch_ref, nil)
     |> assign_message_form("")
     |> stream(:messages, [])
     |> allow_upload(:item_image,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1
     )}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> maybe_subscribe(workspace.id)
         |> load_workspace(workspace)
         |> apply_step(params)}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  defp apply_step(socket, params) do
    case params["step"] do
      step when step in ["business", "products", "cta", "meta"] ->
        assign(socket, :active_step, String.to_existing_atom(step))

      _ ->
        socket
    end
  end

  # --- step navigation ----------------------------------------------------

  @impl true
  def handle_event("goto_step", %{"step" => step}, socket) do
    {:noreply, assign(socket, :active_step, to_step(step))}
  end

  def handle_event("next_step", _params, socket) do
    {:noreply, assign(socket, :active_step, step_offset(socket.assigns.active_step, 1))}
  end

  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :active_step, step_offset(socket.assigns.active_step, -1))}
  end

  def handle_event("set_lang", %{"lang" => lang}, socket) do
    {:noreply, assign(socket, :lang, lang)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # --- business profile ---------------------------------------------------

  def handle_event("validate_business", %{"workspace" => params}, socket) do
    changeset =
      socket.assigns.workspace
      |> Workspaces.change_workspace(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, :business_form, changeset)}
  end

  def handle_event("save_business", %{"workspace" => params}, socket) do
    case Workspaces.update_workspace(socket.assigns.workspace, params) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign_form(:business_form, Workspaces.change_workspace(workspace))
         |> put_flash(:info, "Business profile saved.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, :business_form, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("set_data_source", %{"source" => source}, socket)
      when source in ["manual", "api"] do
    case Workspaces.update_workspace(socket.assigns.workspace, %{"data_source" => source}) do
      {:ok, workspace} ->
        label = if source == "api", do: "Live Sync (JSON API)", else: "Manual Catalog"

        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> put_flash(:info, "#{label} is now the active AI source.")
         |> reload_preview()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not change the active data source.")}
    end
  end

  def handle_event("regenerate_ai_context", _params, socket) do
    {:noreply, regenerate_ai_context(socket)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> clear_item_uploads()
     |> assign(:active_modal, nil)}
  end

  # --- products: JSON endpoint --------------------------------------------

  def handle_event("validate", %{"endpoint" => endpoint_params}, socket) do
    changeset =
      socket.assigns.endpoint
      |> current_endpoint(socket.assigns.workspace.id)
      |> Endpoints.change_endpoint(endpoint_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, :endpoint_form, changeset)}
  end

  def handle_event("submit", %{"endpoint" => endpoint_params}, socket) do
    case Map.get(endpoint_params, "action", "save") do
      "test" -> test_connection(socket, endpoint_params)
      _ -> save_endpoint(socket, endpoint_params)
    end
  end

  # --- products: manual catalog -------------------------------------------

  def handle_event("validate_model", %{"catalog" => catalog_params}, socket) do
    changeset =
      socket.assigns.catalog
      |> Catalogs.change_catalog(catalog_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, :catalog_form, changeset)}
  end

  def handle_event("save_model", %{"catalog" => catalog_params}, socket) do
    case Catalogs.upsert_catalog(socket.assigns.workspace.id, catalog_params) do
      {:ok, _catalog} ->
        {:noreply,
         socket
         |> put_flash(:info, "Manual catalog saved. You can now add fields and items.")
         |> assign(:active_modal, nil)
         |> reload_products_state()}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, :catalog_form, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("open_model", _params, socket) do
    {:noreply,
     socket
     |> assign_form(:catalog_form, Catalogs.change_catalog(socket.assigns.catalog))
     |> assign(:active_modal, :model)}
  end

  def handle_event("validate_field", %{"field" => field_params}, socket) do
    changeset =
      socket.assigns.selected_field
      |> current_field(socket.assigns.catalog.id)
      |> Catalogs.change_field(field_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, :field_form, changeset)}
  end

  def handle_event("save_field", %{"field" => field_params}, socket) do
    case Catalogs.upsert_field(socket.assigns.catalog, field_params) do
      {:ok, _field} ->
        {:noreply,
         socket
         |> put_flash(:info, "Field saved to the model.")
         |> assign(:active_modal, nil)
         |> assign(:selected_field, nil)
         |> reload_products_state(clear_selected_item: false)}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, :field_form, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("new_field", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_field, nil)
     |> assign_form(:field_form, Catalogs.change_field(blank_field(socket.assigns.catalog.id)))
     |> assign(:active_modal, :field)}
  end

  def handle_event("edit_field", %{"id" => id}, socket) do
    field = Catalogs.get_field!(socket.assigns.catalog.id, normalize_id(id))

    {:noreply,
     socket
     |> assign(:selected_field, field)
     |> assign_form(:field_form, Catalogs.change_field(field))
     |> assign(:active_modal, :field)}
  end

  def handle_event("delete_field", %{"id" => id}, socket) do
    field = Catalogs.get_field!(socket.assigns.catalog.id, normalize_id(id))
    {:ok, _} = Catalogs.delete_field(field)

    {:noreply,
     socket
     |> put_flash(:info, "Field removed from the model.")
     |> reload_products_state(clear_selected_item: false)}
  end

  def handle_event("validate_item", %{"item" => item_params}, socket) do
    changeset =
      socket.assigns.selected_item
      |> current_item(socket.assigns.catalog.id)
      |> Catalogs.change_item(item_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, :item_form, changeset)}
  end

  def handle_event("save_item", %{"item" => item_params}, socket) do
    item_params =
      case consume_item_image_upload(socket, socket.assigns.catalog.id) do
        nil -> item_params
        image_url -> Map.put(item_params, "image_url", image_url)
      end

    case Catalogs.upsert_item(socket.assigns.catalog, item_params) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> clear_item_uploads()
         |> put_flash(:info, "Item saved.")
         |> assign(:active_modal, nil)
         |> reload_products_state()}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, :item_form, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("new_item", _params, socket) do
    {:noreply,
     socket
     |> clear_item_uploads()
     |> assign(:selected_item, nil)
     |> assign(:item_values, %{})
     |> assign_form(:item_form, Catalogs.change_item(blank_item(socket.assigns.catalog.id)))
     |> assign(:active_modal, :item)}
  end

  def handle_event("edit_item", %{"id" => id}, socket) do
    item = Catalogs.get_item!(socket.assigns.catalog.id, normalize_id(id))

    {:noreply,
     socket
     |> clear_item_uploads()
     |> assign(:selected_item, item)
     |> assign(:item_values, item.metadata || %{})
     |> assign_form(:item_form, Catalogs.change_item(item))
     |> assign(:active_modal, :item)}
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    item = Catalogs.get_item!(socket.assigns.catalog.id, normalize_id(id))
    {:ok, _} = Catalogs.delete_item(item)

    {:noreply,
     socket
     |> put_flash(:info, "Item deleted.")
     |> reload_products_state()}
  end

  # --- cta rules ----------------------------------------------------------

  def handle_event("open_add_rule", _params, socket) do
    next_priority = CTARules.next_priority(socket.assigns.workspace.id)
    rule_form = RuleForm.blank(next_priority)

    {:noreply,
     socket
     |> assign(:editing_rule, nil)
     |> assign(:active_modal, :cta_rule)
     |> assign_cta_form(RuleForm.changeset(rule_form), rule_form)}
  end

  def handle_event("edit_rule", %{"id" => id}, socket) do
    rule = CTARules.get_cta_rule!(id, socket.assigns.workspace.id)
    rule_form = RuleForm.from_rule(rule)

    {:noreply,
     socket
     |> assign(:editing_rule, rule)
     |> assign(:active_modal, :cta_rule)
     |> assign_cta_form(RuleForm.changeset(rule_form), rule_form)}
  end

  def handle_event("validate_rule", %{"cta_rule_form" => rule_params}, socket) do
    changeset =
      socket.assigns.rule_form_data
      |> RuleForm.changeset(rule_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_cta_form(socket, changeset, Ecto.Changeset.apply_changes(changeset))}
  end

  def handle_event("save_rule", %{"cta_rule_form" => rule_params}, socket) do
    changeset =
      socket.assigns.rule_form_data
      |> RuleForm.changeset(rule_params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      persist_rule(socket, Ecto.Changeset.apply_changes(changeset))
    else
      {:noreply, assign_cta_form(socket, changeset, Ecto.Changeset.apply_changes(changeset))}
    end
  end

  def handle_event("delete_rule", %{"id" => id}, socket) do
    rule = CTARules.get_cta_rule!(id, socket.assigns.workspace.id)
    {:ok, _rule} = CTARules.delete_cta_rule(rule)

    {:noreply,
     socket
     |> put_flash(:info, "CTA rule deleted.")
     |> reload_cta_state()}
  end

  def handle_event("recommend_ctas", _params, socket) do
    if socket.assigns.recommending do
      {:noreply, socket}
    else
      workspace = socket.assigns.workspace

      context =
        Catalogs.build_workspace_context(
          workspace.id,
          endpoint_cached_data(socket.assigns.endpoint),
          workspace.data_source
        )

      ref = System.unique_integer([:positive, :monotonic])

      {:noreply,
       socket
       |> assign(:recommending, true)
       |> assign(:recommend_ref, ref)
       |> start_async({:recommend_ctas, ref}, fn ->
         CtaRecommender.recommend(workspace, context)
       end)}
    end
  end

  def handle_event("add_suggestion", %{"index" => index}, socket) do
    suggestions = socket.assigns.cta_suggestions

    case Enum.at(suggestions, normalize_id(index)) do
      nil ->
        {:noreply, socket}

      suggestion ->
        attrs =
          Map.put(suggestion, "priority", CTARules.next_priority(socket.assigns.workspace.id))

        case CTARules.create_cta_rule(socket.assigns.workspace.id, attrs) do
          {:ok, _rule} ->
            remaining = List.delete_at(suggestions, normalize_id(index))

            {:noreply,
             socket
             |> put_flash(:info, "CTA rule added.")
             |> reload_cta_state()
             |> assign(:cta_suggestions, remaining)}

          {:error, %Changeset{}} ->
            {:noreply, put_flash(socket, :error, "Could not add that suggestion.")}
        end
    end
  end

  def handle_event("dismiss_suggestion", %{"index" => index}, socket) do
    {:noreply,
     assign(
       socket,
       :cta_suggestions,
       List.delete_at(socket.assigns.cta_suggestions, normalize_id(index))
     )}
  end

  # --- meta ---------------------------------------------------------------

  def handle_event("validate", %{"connection" => params}, socket) do
    changeset =
      socket.assigns.connection
      |> Meta.change_connection(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, :meta_form, changeset)}
  end

  def handle_event("save", %{"connection" => params}, socket) do
    case Meta.upsert_connection(socket.assigns.workspace.id, params) do
      {:ok, connection} ->
        {:noreply,
         socket
         |> assign(:connection, connection)
         |> assign(:meta_configured, connection.status == "active")
         |> assign_form(:meta_form, Meta.change_connection(connection))
         |> put_flash(:info, "Meta credentials saved. Now configure the webhook below.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, :meta_form, Map.put(changeset, :action, :validate))}
    end
  end

  # --- playground ---------------------------------------------------------

  def handle_event("send_message", %{"playground" => %{"message" => message}}, socket) do
    dispatch_message(socket, message)
  end

  def handle_event("send_interactive_message", %{"message" => message}, socket) do
    dispatch_message(socket, message)
  end

  def handle_event("clear_chat", _params, socket) do
    if socket.assigns.conversation do
      {:ok, _conversation} = Conversations.delete_conversation(socket.assigns.conversation)
      Conversations.broadcast_playground_cleared(socket.assigns.workspace.id)
    end

    {:noreply, reset_playground(socket)}
  end

  @impl true
  def handle_async({:dispatch_message, dispatch_ref}, {:ok, {:ok, %{prepared: prepared}}}, socket) do
    if socket.assigns.active_dispatch_ref == dispatch_ref do
      {:noreply,
       socket
       |> assign(
         :endpoint,
         Endpoints.get_endpoint(socket.assigns.workspace.id) || prepared.endpoint
       )
       |> assign(:pending_user_message, nil)
       |> assign(:assistant_pending, false)
       |> assign(:active_dispatch_ref, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:dispatch_message, dispatch_ref}, {:ok, {:error, reason}}, socket) do
    {:noreply, fail_dispatch(socket, dispatch_ref, reason)}
  end

  def handle_async({:dispatch_message, dispatch_ref}, {:exit, reason}, socket) do
    {:noreply, fail_dispatch(socket, dispatch_ref, reason)}
  end

  def handle_async({:recommend_ctas, ref}, {:ok, {:ok, suggestions}}, socket) do
    if socket.assigns.recommend_ref == ref do
      socket =
        socket
        |> assign(:recommending, false)
        |> assign(:recommend_ref, nil)
        |> assign(:cta_suggestions, suggestions)

      socket =
        if suggestions == [] do
          put_flash(
            socket,
            :info,
            "No suggestions returned. Add more product data and try again."
          )
        else
          socket
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:recommend_ctas, ref}, {:ok, {:error, reason}}, socket) do
    {:noreply, fail_recommend(socket, ref, reason)}
  end

  def handle_async({:recommend_ctas, ref}, {:exit, reason}, socket) do
    {:noreply, fail_recommend(socket, ref, reason)}
  end

  @impl true
  def handle_info({:new_message, %Message{} = message}, socket) do
    if MapSet.member?(socket.assigns.message_ids, message.id) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> reconcile_pending_state(message)
       |> stream_new_messages([message])}
    end
  end

  def handle_info({:conversation_cleared, workspace_id}, socket) do
    if socket.assigns.workspace && socket.assigns.workspace.id == workspace_id do
      {:noreply, reset_playground(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:endpoint_refreshed, workspace_id}, socket) do
    if socket.assigns.workspace && socket.assigns.workspace.id == workspace_id do
      {:noreply, assign(socket, :endpoint, Endpoints.get_endpoint(workspace_id))}
    else
      {:noreply, socket}
    end
  end

  # ========================================================================
  # render
  # ========================================================================

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:custom_fields, custom_fields(assigns[:catalog]))
      |> assign(:step_number, step_index(assigns.active_step))

    ~H"""
    <section :if={@workspace} class="space-y-5">
      <nav class="flex items-center gap-1.5 text-[13px] text-n500">
        <.link navigate={~p"/workspaces"} class="transition hover:text-n400">Workspaces</.link>
        <span>/</span>
        <span class="text-n400">{@workspace.name}</span>
      </nav>

      <div class="flex min-h-[680px] overflow-hidden rounded-2xl border border-n300 bg-n200 shadow-[0_8px_24px_rgba(0,0,0,0.05)]">
        <%!-- LEFT: guided configuration workspace --%>
        <main class="flex-1 overflow-y-auto p-4 max-h-[calc(100vh-150px)]">
          <div class="mx-auto w-[100%]">
            <%!-- sticky progress workflow header --%>
            <div class="mb-8 flex flex-col gap-4 border-b border-n300 pb-6 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <div class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-primary">
                  <.icon name="hero-swatch-mini" class="h-4 w-4" />
                  <span>Workspace Engine Construction</span>
                </div>
                <h1 class="mt-1 text-3xl font-bold text-n900">{@workspace.name}</h1>
              </div>

              <div class="flex items-center gap-4 rounded-lg border border-n100 bg-n50 p-3 text-sm text-n500 shadow-sm">
                <div class="text-right">
                  <span class="block font-semibold text-primary">Step {@step_number} of 4</span>
                  <span class="text-xs font-light text-n400">{step_caption(@active_step)}</span>
                </div>
                <div class="relative h-3 w-28 overflow-hidden rounded-full bg-n300">
                  <div
                    class="h-full rounded-full bg-primary transition-all duration-500 ease-out"
                    style={"width: #{round(@step_number / 4 * 100)}%"}
                  >
                  </div>
                </div>
              </div>
            </div>

            <%!-- step tabs --%>
            <div class="mb-6 flex flex-wrap items-center gap-2">
              <.step_pill step={:business} active={@active_step} index="1" label="Business" />
              <.step_chevron />
              <.step_pill step={:products} active={@active_step} index="2" label="Products" />
              <.step_chevron />
              <.step_pill step={:cta} active={@active_step} index="3" label="CTA Rules" />
              <.step_chevron />
              <.step_pill step={:meta} active={@active_step} index="4" label="Meta" />
            </div>

            <%!-- active content card --%>
            <div class="rounded-lg border border-n100 bg-n50 p-6 shadow-[0_8px_24px_rgba(0,0,0,0.04)] lg:p-8">
              <.business_step :if={@active_step == :business} {assigns} />
              <.products_step :if={@active_step == :products} {assigns} />
              <.cta_step :if={@active_step == :cta} {assigns} />
              <.meta_step :if={@active_step == :meta} {assigns} />

              <%!-- workflow actions --%>
              <div class="mt-10 flex items-center justify-between border-t border-n300 pt-6">
                <button
                  type="button"
                  phx-click="prev_step"
                  disabled={@active_step == :business}
                  class="inline-flex items-center gap-2 rounded-lg border border-n100 bg-n50 px-4 py-2 text-sm font-medium text-n800 shadow-[0_4px_8px_rgba(0,0,0,0.06)] transition hover:border-primary disabled:cursor-not-allowed disabled:opacity-40"
                >
                  <.icon name="hero-arrow-left-mini" class="h-4 w-4" />
                  <span>Back</span>
                </button>

                <button
                  :if={@active_step != :meta}
                  type="button"
                  phx-click="next_step"
                  class="inline-flex items-center gap-2 rounded-lg border border-primary bg-primary px-4 py-2 text-sm font-medium text-n50 transition hover:opacity-90"
                >
                  <span>{next_label(@active_step)}</span>
                  <.icon name="hero-arrow-right-mini" class="h-4 w-4" />
                </button>

                <.link
                  :if={@active_step == :meta}
                  navigate={~p"/workspaces"}
                  class="inline-flex items-center gap-2 rounded-lg border border-primary bg-primary px-4 py-2 text-sm font-medium text-n50 transition hover:opacity-90"
                >
                  <span>Finish setup</span>
                  <.icon name="hero-check-mini" class="h-4 w-4" />
                </.link>
              </div>
            </div>
          </div>
        </main>

        <%!-- RIGHT: persistent live playground sidebar --%>
        <.playground_panel {assigns} />
      </div>

      <.catalog_model_modal :if={@active_modal == :model} {assigns} />
      <.field_modal :if={@active_modal == :field} {assigns} />
      <.item_modal :if={@active_modal == :item} {assigns} />
      <.cta_rule_modal :if={@active_modal == :cta_rule} {assigns} />
    </section>
    """
  end

  # --- stepper chrome -----------------------------------------------------

  attr :step, :atom, required: true
  attr :active, :atom, required: true
  attr :index, :string, required: true
  attr :label, :string, required: true

  defp step_pill(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="goto_step"
      phx-value-step={@step}
      class={[
        "inline-flex items-center gap-2 rounded-full border px-3.5 py-1.5 text-sm font-medium transition",
        (@active == @step && "border-primary bg-primary-light text-primary") ||
          "border-n300 bg-n50 text-n500 hover:border-primary/40 hover:text-n800"
      ]}
    >
      <span class={[
        "flex h-5 w-5 items-center justify-center rounded-full text-[11px] font-semibold",
        (@active == @step && "bg-primary text-n50") || "bg-n200 text-n500"
      ]}>
        {@index}
      </span>
      {@label}
    </button>
    """
  end

  defp step_chevron(assigns) do
    ~H"""
    <.icon name="hero-chevron-right-mini" class="h-4 w-4 text-n400" />
    """
  end

  # --- step 1: business profile -------------------------------------------

  defp business_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-xl font-semibold text-n900">Business Profile</h3>
        <p class="mt-1 text-sm text-n400">
          Tell the assistant who you are. This context grounds every reply and powers
          smart CTA recommendations — your phone and location feed call, WhatsApp, and
          map CTAs automatically.
        </p>
      </div>

      <.simple_form for={@business_form} phx-change="validate_business" phx-submit="save_business">
        <div class="grid gap-4 sm:grid-cols-2">
          <.input
            field={@business_form[:company_name]}
            label="Company name"
            placeholder="Acme Retailers Ltd"
          />
          <.input
            field={@business_form[:industry]}
            label="Industry"
            placeholder="Fashion, Electronics, Food..."
          />
          <.input
            field={@business_form[:phone_number]}
            label="Phone number"
            placeholder="+254700000000"
          />
          <.input
            field={@business_form[:location]}
            label="Location"
            placeholder="Moi Avenue, Nairobi"
          />
        </div>
        <.input
          field={@business_form[:about]}
          type="textarea"
          label="About the business"
          placeholder="What you sell, who you serve, your hours, delivery options, and anything the assistant should know."
        />

        <:actions>
          <.button>Save business profile</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  # --- step 2: products ---------------------------------------------------

  defp products_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-xl font-semibold text-n900">Product Data Ingestion</h3>
        <p class="mt-1 text-sm text-n400">
          Curate products manually, or connect a live JSON feed. Mark one as the active source —
          the AI reads only that source as its business context.
        </p>
      </div>

      <div class="flex gap-6 border-b border-n300">
        <.tab_button
          tab="manual"
          active={@active_tab}
          label="Manual Catalog"
          icon="hero-squares-2x2-mini"
        />
        <.tab_button
          tab="api"
          active={@active_tab}
          label="Live Sync (JSON API)"
          icon="hero-bolt-mini"
        />
        <.tab_button
          tab="preview"
          active={@active_tab}
          label="AI Context"
          icon="hero-code-bracket-mini"
        />
      </div>

      <%!-- Manual catalog --%>
      <div :if={@active_tab == "manual"} class="space-y-6">
        <.source_banner source="manual" active={@workspace.data_source} />
        <div :if={!@catalog.id} class="space-y-6">
          <.empty_state
            icon="hero-squares-2x2"
            title="Set up your catalog model"
            body="Define a reusable schema for this shop, then add fields and items one by one without touching JSON."
          >
            <button
              type="button"
              phx-click="open_model"
              class="inline-flex items-center gap-2 rounded-lg border border-primary bg-primary px-4 py-2 text-sm font-medium text-n50 transition hover:opacity-90"
            >
              <.icon name="hero-sparkles-mini" class="h-4 w-4" /> Set up catalog model
            </button>
          </.empty_state>
        </div>

        <div :if={@catalog.id} class="space-y-6">
          <%!-- fields --%>
          <div class="rounded-lg border border-n300 bg-n100/40 p-4">
            <div class="flex items-center justify-between">
              <p class="text-[11px] font-semibold uppercase tracking-wider text-n400">
                Custom fields
              </p>
              <button
                type="button"
                phx-click="new_field"
                class="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
              >
                <.icon name="hero-plus-mini" class="h-4 w-4" /> Add field
              </button>
            </div>
            <div class="mt-3 flex flex-wrap gap-2">
              <span
                :for={field <- @catalog.fields || []}
                class="group inline-flex items-center gap-1.5 rounded-full border border-n300 bg-n50 px-3 py-1 text-xs text-n800"
              >
                <span class="font-medium">{field.label}</span>
                <span class="font-mono text-n400">{field.field_type}</span>
                <button
                  type="button"
                  phx-click="edit_field"
                  phx-value-id={field.id}
                  class="text-n400 hover:text-primary"
                >
                  <.icon name="hero-pencil-square-mini" class="h-3.5 w-3.5" />
                </button>
                <button
                  type="button"
                  phx-click="delete_field"
                  phx-value-id={field.id}
                  data-confirm="Remove this field from the model?"
                  class="text-n400 hover:text-red-600"
                >
                  <.icon name="hero-x-mark-mini" class="h-3.5 w-3.5" />
                </button>
              </span>
              <span :if={@catalog.fields == []} class="text-xs text-n400">
                No extra fields yet. Core fields are already built in, and custom fields stay optional.
              </span>
            </div>
          </div>

          <div class="rounded-lg border border-n300 bg-n50 p-4">
            <p class="text-[11px] font-semibold uppercase tracking-wider text-n400">
              Base fields
            </p>
            <p class="mt-1 text-sm text-n500">
              Every item already has these core fields. Keep custom fields for anything shop-specific.
            </p>
            <div class="mt-3 flex flex-wrap gap-2">
              <span class="inline-flex items-center rounded-full bg-primary-light px-3 py-1 text-xs font-medium text-primary">
                Title
              </span>
              <span class="inline-flex items-center rounded-full bg-primary-light px-3 py-1 text-xs font-medium text-primary">
                Description
              </span>
              <span class="inline-flex items-center rounded-full bg-primary-light px-3 py-1 text-xs font-medium text-primary">
                Price
              </span>
              <span class="inline-flex items-center rounded-full bg-primary-light px-3 py-1 text-xs font-medium text-primary">
                Currency
              </span>
              <span class="inline-flex items-center rounded-full bg-primary-light px-3 py-1 text-xs font-medium text-primary">
                URL
              </span>
              <span class="inline-flex items-center rounded-full bg-primary-light px-3 py-1 text-xs font-medium text-primary">
                Image
              </span>
              <span class="inline-flex items-center rounded-full bg-primary-light px-3 py-1 text-xs font-medium text-primary">
                Status
              </span>
            </div>
          </div>

          <%!-- items as cards --%>
          <div class="grid gap-4 sm:grid-cols-2">
            <div
              :for={item <- @catalog.items || []}
              class="group flex items-center justify-between rounded-lg border border-n300 bg-n50 p-4 transition-all hover:border-primary/30"
            >
              <div class="flex min-w-0 items-center gap-3">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-md border border-n300 bg-n200 text-n500">
                  <img
                    :if={item.image_url}
                    src={item.image_url}
                    alt={item.title}
                    class="h-full w-full object-cover"
                  />
                  <.icon :if={!item.image_url} name="hero-photo" class="h-6 w-6" />
                </div>
                <div class="min-w-0">
                  <h4 class="truncate text-sm font-semibold text-n900">{item.title}</h4>
                  <p class="truncate font-mono text-xs text-n400">
                    {item.currency || "—"}{if item.price, do: " #{item.price}", else: ""}
                  </p>
                </div>
              </div>
              <div class="flex shrink-0 items-center gap-1">
                <span class="inline-flex items-center rounded-full bg-primary-light px-2.5 py-0.5 text-xs font-medium text-primary">
                  {item.status || "active"}
                </span>
                <button
                  type="button"
                  phx-click="edit_item"
                  phx-value-id={item.id}
                  class="p-1 text-n400 hover:text-n900"
                >
                  <.icon name="hero-pencil-square-mini" class="h-4 w-4" />
                </button>
                <button
                  type="button"
                  phx-click="delete_item"
                  phx-value-id={item.id}
                  data-confirm="Delete this item?"
                  class="p-1 text-n400 hover:text-red-600"
                >
                  <.icon name="hero-trash-mini" class="h-4 w-4" />
                </button>
              </div>
            </div>

            <%!-- add item card --%>
            <button
              type="button"
              phx-click="new_item"
              class="group flex items-center justify-center gap-3 rounded-lg border border-dashed border-n400 bg-n100/50 p-4 transition-all duration-300 hover:border-primary/50 hover:bg-primary-light/40"
            >
              <span class="flex h-8 w-8 items-center justify-center rounded-full bg-n50 text-n500 transition-all group-hover:bg-primary group-hover:text-n50">
                <.icon name="hero-plus-mini" class="h-4 w-4" />
              </span>
              <span class="text-sm font-medium text-n600 transition-colors group-hover:text-primary">
                Append New Catalog Item
              </span>
            </button>
          </div>
        </div>
      </div>

      <%!-- JSON API --%>
      <div :if={@active_tab == "api"} class="space-y-5">
        <.source_banner source="api" active={@workspace.data_source} />
        <div
          :if={@endpoint.last_fetched_at}
          class="flex items-center gap-2 rounded-lg border border-[#B7EBCF] bg-[#E8FFF3] px-4 py-2.5 text-[13px] font-medium text-primary"
        >
          <.icon name="hero-check-circle-mini" class="h-4 w-4" />
          Last fetched: {last_fetched_label(@endpoint.last_fetched_at)}
        </div>

        <div
          :if={@test_error}
          role="alert"
          class="flex items-start gap-2 rounded-lg border border-[#FFCDD2] border-l-4 border-l-red-500 bg-red-50 px-4 py-3 text-[13px] text-n600"
        >
          <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-4 w-4 flex-none text-red-500" />
          <span>{@test_error}</span>
        </div>

        <.simple_form for={@endpoint_form} phx-change="validate" phx-submit="submit">
          <.input field={@endpoint_form[:url]} label="URL" required />
          <.input
            field={@endpoint_form[:method]}
            type="select"
            label="Method"
            options={[{"GET", "GET"}, {"POST", "POST"}]}
          />
          <.input
            field={@endpoint_form[:headers_text]}
            type="textarea"
            label="Headers"
            placeholder="Authorization: Bearer token\nAccept: application/json"
          />
          <.input
            :if={@endpoint_form[:method].value == "POST"}
            field={@endpoint_form[:body_template]}
            type="textarea"
            label="Body template"
            placeholder={"{\"query\": \"{{query}}\"}"}
          />
          <.input
            field={@endpoint_form[:refresh_strategy]}
            type="select"
            label="Refresh strategy"
            options={[
              {"On demand", "on_demand"},
              {"Every 60s", "poll_60s"},
              {"Every 5 min", "poll_300s"}
            ]}
          />

          <:actions>
            <button
              type="submit"
              name="endpoint[action]"
              value="test"
              class="inline-flex items-center justify-center rounded-lg border border-n300 bg-n50 px-4 py-2 text-sm font-medium text-n800 transition hover:border-primary"
            >
              Test connection
            </button>
            <.button name="endpoint[action]" value="save">Save endpoint</.button>
          </:actions>
        </.simple_form>
      </div>

      <%!-- AI context preview --%>
      <div :if={@active_tab == "preview"} class="space-y-3">
        <div class="flex items-start justify-between gap-4">
          <div class="flex items-center gap-2 rounded-lg border border-n300 bg-n100 px-4 py-2.5 text-[13px] text-n500">
            <.icon name="hero-check-badge-mini" class="h-4 w-4 flex-none text-primary" />
            <span>
              Active source:
              <span class="font-semibold text-n900">
                {if @workspace.data_source == "api",
                  do: "Live Sync (JSON API)",
                  else: "Manual Catalog"}
              </span>
            </span>
          </div>
          <button
            type="button"
            phx-click="regenerate_ai_context"
            phx-disable-with="Regenerating..."
            class="inline-flex shrink-0 items-center gap-1.5 rounded-lg border border-n300 bg-n50 px-3 py-2 text-sm font-medium text-n800 transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-arrow-path" class="h-4 w-4" /> Regenerate AI context
          </button>
        </div>
        <p class="text-sm text-n400">
          {@preview_label || "The shared business context"} the assistant reads for this workspace.
        </p>
        <div :if={@preview_json} class="overflow-hidden rounded-lg border border-n300 bg-n50">
          <pre class="code-panel overflow-x-auto px-5 py-4"><%= @preview_json %></pre>
        </div>
        <p :if={!@preview_json} class="text-sm text-n400">
          Nothing to preview yet. Add catalog items or connect an API first.
        </p>
      </div>
    </div>
    """
  end

  

  # --- step 3: cta rules --------------------------------------------------

  defp cta_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h3 class="text-xl font-semibold text-n900">Intent Parsing Call-to-Actions</h3>
          <p class="mt-1 text-sm text-n400">
            Direct the AI assistant to provide interactive links or triggers based on user queries.
          </p>
        </div>
        <div :if={@cta_rules != []} class="flex shrink-0 items-center gap-2">
          <.recommend_button recommending={@recommending} variant="secondary" />
          <button
            type="button"
            phx-click="open_add_rule"
            class="inline-flex items-center gap-1.5 rounded-lg border border-primary bg-primary px-3 py-1.5 text-sm font-medium text-n50 transition hover:opacity-90"
          >
            <.icon name="hero-plus-mini" class="h-4 w-4" /> Add rule
          </button>
        </div>
      </div>

      <.cta_suggestions :if={@cta_suggestions != []} suggestions={@cta_suggestions} />

      <.empty_state
        :if={@cta_rules == [] and @cta_suggestions == []}
        icon="hero-bolt"
        title="No Custom Response Rules Established"
        body="Tell the assistant which call-to-action to attach when a buyer asks for the next step — price, location, or how to order. Or let AI suggest rules from your products."
      >
        <div class="flex flex-wrap items-center justify-center gap-2">
          <.recommend_button recommending={@recommending} variant="primary" />
          <button
            type="button"
            phx-click="open_add_rule"
            class="inline-flex items-center gap-2 rounded-lg border border-n300 bg-n50 px-4 py-2 text-sm font-medium text-n800 transition hover:border-primary"
          >
            <.icon name="hero-plus-mini" class="h-4 w-4" /> Add manually
          </button>
        </div>
      </.empty_state>

      <div :if={@cta_rules != []} class="space-y-4">
        <div
          :for={rule <- @cta_rules}
          id={"cta-rule-#{rule.id}"}
          class="group rounded-lg border border-n300 bg-n50 p-5 transition-all duration-300 hover:border-primary/40 hover:shadow-[0_4px_16px_rgba(15,156,92,0.04)]"
        >
          <div class="flex flex-col justify-between gap-4 md:flex-row md:items-center">
            <div class="flex items-start gap-3.5">
              <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary text-n50 shadow-sm shadow-primary/20">
                <.icon name={cta_icon(rule.cta_type)} class="h-5 w-5" />
              </div>
              <div>
                <div class="flex flex-wrap items-center gap-2">
                  <span class="text-xs font-semibold uppercase tracking-wider text-n400">
                    Rule #{rule.priority}
                  </span>
                  <span class="inline-flex items-center rounded-md border border-primary/10 bg-primary-light px-2 py-0.5 text-xs font-medium text-primary">
                    {humanize_cta_type(rule.cta_type)}
                  </span>
                </div>
                <h4 class="mt-0.5 text-base font-semibold text-n900">{rule.trigger_description}</h4>
              </div>
            </div>

            <div class="flex items-center justify-between gap-6 border-t border-n200 pt-3 md:justify-end md:border-t-0 md:pt-0">
              <div class="md:text-right">
                <span class="block text-[11px] font-bold uppercase tracking-wider text-n400">
                  Payload
                </span>
                <span class="mt-0.5 block truncate rounded border border-n300 bg-n200 px-2 py-1 font-mono text-sm text-n800 md:max-w-[220px]">
                  {payload_summary(rule)}
                </span>
              </div>
              <div class="flex items-center gap-2">
                <button
                  type="button"
                  phx-click="edit_rule"
                  phx-value-id={rule.id}
                  class="rounded-md p-2 text-n500 transition-colors hover:bg-primary-light hover:text-primary"
                >
                  <.icon name="hero-pencil-square-mini" class="h-4 w-4" />
                </button>
                <button
                  type="button"
                  phx-click="delete_rule"
                  phx-value-id={rule.id}
                  data-confirm="Delete this CTA rule?"
                  class="rounded-md p-2 text-n400 transition-colors hover:bg-red-50 hover:text-red-600"
                >
                  <.icon name="hero-trash-mini" class="h-4 w-4" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :recommending, :boolean, required: true
  attr :variant, :string, default: "secondary"

  defp recommend_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="recommend_ctas"
      disabled={@recommending}
      class={[
        "inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium transition disabled:cursor-not-allowed disabled:opacity-60",
        (@variant == "primary" && "border border-primary bg-primary text-n50 hover:opacity-90") ||
          "border border-primary bg-primary-light text-primary hover:bg-primary hover:text-n50"
      ]}
    >
      <.icon
        name={if @recommending, do: "hero-arrow-path-mini", else: "hero-sparkles-mini"}
        class={"h-4 w-4 #{if @recommending, do: "animate-spin"}"}
      />
      {if @recommending, do: "Generating...", else: "Recommend based on my product"}
    </button>
    """
  end

  attr :suggestions, :list, required: true

  defp cta_suggestions(assigns) do
    ~H"""
    <div class="space-y-3 rounded-lg border border-primary/30 bg-primary-light/30 p-4">
      <div class="flex items-center gap-2 text-sm font-semibold text-primary">
        <.icon name="hero-sparkles-mini" class="h-4 w-4" />
        AI-suggested rules — review and add the ones you want
      </div>
      <div
        :for={{suggestion, index} <- Enum.with_index(@suggestions)}
        class="flex flex-col gap-3 rounded-lg border border-n300 bg-n50 p-4 sm:flex-row sm:items-center sm:justify-between"
      >
        <div class="flex items-start gap-3">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary-light text-primary">
            <.icon name={cta_icon(suggestion["cta_type"])} class="h-4 w-4" />
          </div>
          <div class="min-w-0">
            <span class="inline-flex items-center rounded-md border border-primary/10 bg-primary-light px-2 py-0.5 text-xs font-medium text-primary">
              {humanize_cta_type(suggestion["cta_type"])}
            </span>
            <h4 class="mt-1 text-sm font-semibold text-n900">{suggestion["trigger_description"]}</h4>
            <p class="mt-0.5 truncate font-mono text-xs text-n400">
              {suggestion_summary(suggestion)}
            </p>
          </div>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <button
            type="button"
            phx-click="add_suggestion"
            phx-value-index={index}
            class="inline-flex items-center gap-1.5 rounded-lg border border-primary bg-primary px-3 py-1.5 text-sm font-medium text-n50 transition hover:opacity-90"
          >
            <.icon name="hero-plus-mini" class="h-4 w-4" /> Add
          </button>
          <button
            type="button"
            phx-click="dismiss_suggestion"
            phx-value-index={index}
            class="rounded-md p-2 text-n400 transition hover:bg-n200 hover:text-n900"
            aria-label="Dismiss suggestion"
          >
            <.icon name="hero-x-mark-mini" class="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  # --- step 4: meta -------------------------------------------------------

  defp meta_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-xl font-semibold text-n900">Meta Verification Pipeline</h3>
        <p class="mt-1 text-sm text-n400">
          Connect this workspace to the WhatsApp Business Platform. Save your Cloud API
          credentials, then point Meta's webhook at the URL below to go live.
        </p>
      </div>

      <div
        :if={@meta_configured}
        class="flex items-start gap-4 rounded-lg border border-primary/20 bg-primary-light/60 p-4"
      >
        <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary-light text-primary">
          <.icon name="hero-shield-check-mini" class="h-5 w-5" />
        </div>
        <div>
          <h4 class="text-sm font-semibold text-n900">Pre-Live Stage Validated</h4>
          <p class="mt-0.5 text-xs leading-relaxed text-n400">
            Your catalog and message parser are live. Secure token pipelines to operate over
            production WhatsApp.
          </p>
        </div>
      </div>

      <div
        :for={alert <- meta_alerts(@connection, @data_ingestion_configured, @cta_rules_configured)}
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

      <div
        :if={@connection.last_error}
        role="alert"
        class="flex items-start gap-2 rounded-lg border border-[#FFCDD2] border-l-4 border-l-red-500 bg-red-50 px-4 py-3 text-[13px] text-n600"
      >
        <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-4 w-4 flex-none text-red-500" />
        <span>{@connection.last_error}</span>
      </div>

      <.simple_form for={@meta_form} phx-change="validate" phx-submit="save">
        <div class="grid gap-4 md:grid-cols-2">
          <.input field={@meta_form[:phone_number_id]} label="Phone Number ID" required />
          <.input field={@meta_form[:waba_id]} label="WhatsApp Business Account ID" required />
        </div>
        <.input
          field={@meta_form[:access_token]}
          type="password"
          label="Meta Permanent API Secret Token"
          required
          autocomplete="off"
        />
        <p class="-mt-3 text-[13px] text-n400">
          The access token is encrypted at rest. Saving new credentials resets the connection to
          <span class="font-medium">pending</span>
          until the webhook is re-verified.
        </p>

        <:actions>
          <.button>Save credentials</.button>
        </:actions>
      </.simple_form>

      <div :if={persisted?(@connection)} class="space-y-5 border-t border-n300 pt-6">
        <div>
          <h4 class="text-base font-semibold text-n900">Webhook setup</h4>
          <p class="mt-1 text-sm text-n400">
            In your Meta app, open WhatsApp → Configuration → Webhooks, paste these values, then
            subscribe to the <span class="font-medium">messages</span> field.
          </p>
        </div>
        <.copy_field
          id="webhook-url"
          label="Callback URL"
          value={webhook_url(@socket, @workspace.slug)}
        />
        <.copy_field id="verify-token" label="Verify token" value={@connection.verify_token} />

        <div class="space-y-3 rounded-lg border border-n300 bg-n100/50 p-4 text-sm">
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
    </div>
    """
  end

  # --- right playground sidebar -------------------------------------------

  defp playground_panel(assigns) do
    ~H"""
    <aside class="flex max-h-[calc(100vh-150px)] w-96 min-w-0 shrink-0 flex-col overflow-hidden border-l border-n300 bg-n50 shadow-[-6px_0_24px_rgba(0,0,0,0.03)]">
      <div class="flex items-center justify-between border-b border-n200 bg-n100 p-4">
        <div class="flex min-w-0 items-center gap-3">
          <div class="relative flex h-6 w-6">
            <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-primary opacity-75">
            </span>
            <span class="relative inline-flex h-6 w-6 rounded-full bg-primary"></span>
          </div>
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold text-n900">Whatsapp Simulator</p>
            <p class="truncate text-xs font-light text-n400">
              Connected to: {endpoint_label(@endpoint)}
            </p>
          </div>
        </div>
        <div class="flex items-center gap-1">
          <button
            type="button"
            phx-click="clear_chat"
            aria-label="Clear chat"
            title="Clear chat"
            class="inline-flex h-8 w-8 items-center justify-center rounded-md text-n400 transition hover:bg-n200 hover:text-n900"
          >
            <.icon name="hero-trash-mini" class="h-4 w-4" />
          </button>
        </div>
      </div>

      <div
        id="playground-scroll-region"
        phx-hook="PlaygroundScroll"
        data-message-count={MapSet.size(@message_ids)}
        data-pending={to_string(not is_nil(@pending_user_message) or @assistant_pending)}
        class="flex-1 space-y-3 overflow-y-auto p-4"
        style="background-color: #ECE5DD; background-image: radial-gradient(circle, rgba(0,0,0,0.04) 1px, transparent 1px); background-size: 20px 20px;"
      >
        <div class="flex justify-start">
          <div class="relative max-w-[85%] rounded-lg border border-n100 bg-n50 p-3 text-sm text-n800 shadow-sm">
            <p class="mb-1 text-xs font-medium text-primary">Sokochat System</p>
            Add products or rules on the left, then type a message here to test live parsing logic.
          </div>
        </div>

        <div id="playground-messages" phx-update="stream" class="space-y-2.5">
          <div :for={{dom_id, message} <- @streams.messages} id={dom_id}>
            <.message_bubble message={message} assistant_pending={@assistant_pending} />
          </div>
        </div>

        <div :if={@pending_user_message} class="mt-2.5 flex justify-end">
          <div class="max-w-[80%] rounded-[12px_12px_0_12px] bg-primary px-3.5 py-2.5 text-sm text-n50 opacity-80">
            <p class="whitespace-pre-wrap break-words leading-6">{@pending_user_message.content}</p>
            <div class="mt-1 flex items-center justify-end gap-2 text-[11px] text-n50/70">
              <span>Sending...</span>
            </div>
          </div>
        </div>

        <.typing_indicator :if={@assistant_pending} />
      </div>

      <div class="border-t border-n200 bg-n50 p-4 shadow-[0_-4px_12px_rgba(0,0,0,0.02)]">
        <.form
          for={@message_form}
          as={:playground}
          phx-submit="send_message"
          class="relative flex items-center"
        >
          <input
            type="text"
            name={@message_form[:message].name}
            id={@message_form[:message].id}
            value={@message_form[:message].value}
            placeholder="Type customer text..."
            autocomplete="off"
            disabled={@assistant_pending}
            class="w-full rounded-lg border border-n300 bg-n50 px-4 py-3 pr-12 text-sm text-n800 outline-none transition placeholder:text-n400 focus:border-primary focus:ring-1 focus:ring-primary"
          />
          <button
            type="submit"
            aria-label="Send message"
            disabled={@assistant_pending}
            class="absolute right-2.5 rounded-md p-1.5 text-primary transition hover:bg-primary-light disabled:opacity-50"
          >
            <.icon name="hero-paper-airplane-mini" class="h-5 w-5" />
          </button>
        </.form>
      </div>
    </aside>
    """
  end

  # --- shared small components --------------------------------------------

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true
  slot :inner_block, required: true

  defp empty_state(assigns) do
    ~H"""
    <div class="rounded-lg border border-dashed border-n300 bg-n100/50 px-4 py-10 text-center">
      <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-primary-light text-primary">
        <.icon name={@icon} class="h-6 w-6" />
      </div>
      <h3 class="mt-4 text-sm font-semibold text-n900">{@title}</h3>
      <p class="mx-auto mt-1 max-w-sm text-xs text-n400">{@body}</p>
      <div class="mt-6">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  attr :tab, :string, required: true
  attr :active, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true

  defp tab_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="switch_tab"
      phx-value-tab={@tab}
      class={[
        "flex items-center gap-2 border-b-2 px-1 py-3 text-sm font-medium transition",
        (@active == @tab && "border-primary text-n900") ||
          "border-transparent text-n400 hover:text-n900"
      ]}
    >
      <.icon name={@icon} class="h-4 w-4" />
      {@label}
    </button>
    """
  end

  attr :source, :string, required: true
  attr :active, :string, required: true

  defp source_banner(assigns) do
    assigns = assign(assigns, :is_active, assigns.source == assigns.active)

    ~H"""
    <div
      :if={@is_active}
      class="flex items-center gap-2 rounded-lg border border-[#B7EBCF] bg-[#E8FFF3] px-4 py-2.5 text-[13px] font-medium text-primary"
    >
      <.icon name="hero-check-badge-mini" class="h-4 w-4 flex-none" />
      <span>Active AI source — the assistant reads this data.</span>
    </div>
    <div
      :if={not @is_active}
      class="flex items-center justify-between gap-3 rounded-lg border border-n300 bg-n100 px-4 py-2.5 text-[13px] text-n500"
    >
      <span class="flex items-center gap-2">
        <.icon name="hero-eye-slash-mini" class="h-4 w-4 flex-none" />
        Not the active source — the AI ignores this data right now.
      </span>
      <button
        type="button"
        phx-click="set_data_source"
        phx-value-source={@source}
        class="inline-flex flex-none items-center gap-1.5 rounded-md border border-primary bg-primary px-3 py-1.5 text-xs font-semibold text-n50 transition hover:opacity-90"
      >
        <.icon name="hero-bolt-mini" class="h-3.5 w-3.5" /> Set as AI source
      </button>
    </div>
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

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :width, :string, default: "max-w-lg"
  slot :inner_block, required: true

  defp modal_shell(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50" phx-window-keydown="close_modal" phx-key="escape">
      <div
        class="fixed inset-0 bg-n900/40 transition-opacity"
        phx-click="close_modal"
        aria-hidden="true"
      >
      </div>
      <div class="fixed inset-0 overflow-y-auto p-4 sm:p-6 lg:py-10">
        <div class="flex min-h-full items-start justify-center">
          <div class={[
            "relative w-full rounded-2xl border border-n300 bg-n50 shadow-[0_20px_60px_rgba(0,0,0,0.18)]",
            @width
          ]}>
            <div class="flex items-start justify-between gap-4 border-b border-n300 px-6 py-5">
              <div class="space-y-1">
                <h2 class="text-lg font-semibold text-n900">{@title}</h2>
                <p :if={@subtitle} class="text-sm leading-6 text-n400">{@subtitle}</p>
              </div>
              <button
                type="button"
                phx-click="close_modal"
                class="-m-2 flex-none rounded-full p-2 text-n400 transition hover:bg-n200 hover:text-n900"
                aria-label="Close"
              >
                <.icon name="hero-x-mark-mini" class="h-5 w-5" />
              </button>
            </div>
            <div class="px-6 py-5">{render_slot(@inner_block)}</div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- modals -------------------------------------------------------------

  defp catalog_model_modal(assigns) do
    ~H"""
    <.modal_shell title="Catalog model" subtitle="Define the reusable schema for this shop.">
      <.simple_form for={@catalog_form} phx-change="validate_model" phx-submit="save_model">
        <.input field={@catalog_form[:name]} label="Model name" required />
        <.input
          field={@catalog_form[:entity_label]}
          label="Item label"
          placeholder="product, service, menu item"
          required
        />
        <.input
          field={@catalog_form[:context_notes]}
          type="textarea"
          label="Context notes"
          placeholder="Tell the AI what the catalog means and how to read it."
        />
        <:actions>
          <button
            type="button"
            phx-click="close_modal"
            class="inline-flex items-center justify-center rounded-lg border border-n300 bg-n50 px-4 py-2 text-sm font-medium text-n800 transition hover:bg-n200"
          >
            Cancel
          </button>
          <.button>Save model</.button>
        </:actions>
      </.simple_form>
    </.modal_shell>
    """
  end

  defp field_modal(assigns) do
    ~H"""
    <.modal_shell
      title={if @selected_field, do: "Edit field", else: "Add field"}
      subtitle="Stored on the item metadata and included in the AI context."
    >
      <.simple_form for={@field_form} phx-change="validate_field" phx-submit="save_field">
        <input type="hidden" name="field[id]" value={(@selected_field && @selected_field.id) || ""} />
        <.input
          field={@field_form[:key]}
          label="Field key"
          placeholder="color, size, stock_status"
          required
        />
        <.input
          field={@field_form[:field_type]}
          type="select"
          label="Field type"
          options={[
            {"Text", "text"},
            {"Textarea", "textarea"},
            {"Number", "number"},
            {"URL", "url"},
            {"Image URL", "image_url"},
            {"Boolean", "boolean"},
            {"JSON", "json"}
          ]}
        />
        <.input field={@field_form[:required]} type="checkbox" label="Required field" />
        <.input
          field={@field_form[:help_text]}
          type="textarea"
          label="Help text"
          placeholder="Optional guidance for the shop owner"
        />
        <:actions>
          <button
            type="button"
            phx-click="close_modal"
            class="inline-flex items-center justify-center rounded-lg border border-n300 bg-n50 px-4 py-2 text-sm font-medium text-n800 transition hover:bg-n200"
          >
            Cancel
          </button>
          <.button>{if @selected_field, do: "Update field", else: "Add field"}</.button>
        </:actions>
      </.simple_form>
    </.modal_shell>
    """
  end

  defp item_modal(assigns) do
    ~H"""
    <.modal_shell
      width="max-w-2xl"
      title={if @selected_item, do: "Edit item", else: "New item"}
      subtitle="Custom fields are saved separately and included in the AI context."
    >
      <.simple_form for={@item_form} phx-change="validate_item" phx-submit="save_item" multipart>
        <input type="hidden" name="item[id]" value={(@selected_item && @selected_item.id) || ""} />
        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={@item_form[:title]} label="Title" required />
          <.input field={@item_form[:price]} type="number" step="any" label="Price" />
          <.input field={@item_form[:currency]} label="Currency" placeholder="KES, USD, etc." />
          <.input field={@item_form[:url]} type="url" label="URL" />
          <.input
            field={@item_form[:status]}
            type="select"
            label="Status"
            options={[{"Active", "active"}, {"Draft", "draft"}, {"Archived", "archived"}]}
          />
        </div>

        <div class="mt-4 space-y-4 rounded-2xl border border-dashed border-n300 bg-n50/50 p-4">
          <div>
            <h3 class="text-sm font-semibold text-n900">Image</h3>
            <p class="text-xs leading-5 text-n400">
              Upload a JPG, PNG, GIF, or WEBP file, or paste an image URL below.
            </p>
          </div>
          <div class="rounded-xl border border-n300 bg-white px-4 py-3">
            <.live_file_input
              upload={@uploads.item_image}
              class="block w-full cursor-pointer text-sm text-n600 file:mr-4 file:rounded-full file:border-0 file:bg-primary-light file:px-4 file:py-2 file:text-sm file:font-medium file:text-primary hover:file:bg-primary hover:file:text-n50"
            />
          </div>
          <.input
            field={@item_form[:image_url]}
            type="url"
            label="Image URL"
            placeholder="https://example.com/image.jpg"
          />
        </div>

        <.input field={@item_form[:description]} type="textarea" label="Description" class="mt-4" />

        <div
          :if={@custom_fields != []}
          class="mt-6 space-y-4 rounded-2xl border border-dashed border-n300 bg-n50/50 p-4"
        >
          <div>
            <h3 class="text-sm font-semibold text-n900">Custom fields</h3>
            <p class="text-xs leading-5 text-n400">
              These come from the model definition and are stored in the item metadata.
            </p>
          </div>
          <div class="grid gap-4 sm:grid-cols-2">
            <.custom_field :for={field <- @custom_fields} field={field} values={@item_values} />
          </div>
        </div>

        <:actions>
          <button
            type="button"
            phx-click="close_modal"
            class="inline-flex items-center justify-center rounded-lg border border-n300 bg-n50 px-4 py-2 text-sm font-medium text-n800 transition hover:bg-n200"
          >
            Cancel
          </button>
          <.button>{if @selected_item, do: "Update item", else: "Add item"}</.button>
        </:actions>
      </.simple_form>
    </.modal_shell>
    """
  end

  defp cta_rule_modal(assigns) do
    ~H"""
    <.modal_shell
      width="max-w-2xl"
      title={if @editing_rule, do: "Edit CTA rule", else: "Add CTA rule"}
      subtitle="Focus each rule on one buyer intent so the assistant can pick the first matching action."
    >
      <.simple_form for={@cta_form} phx-change="validate_rule" phx-submit="save_rule">
        <.input
          field={@cta_form[:trigger_description]}
          type="textarea"
          label="Trigger description"
          placeholder="When the buyer asks about price or wants to buy"
          required
        />
        <.input
          field={@cta_form[:cta_type]}
          type="select"
          label="CTA type"
          options={RuleForm.cta_type_options()}
        />
        <.input field={@cta_form[:priority]} type="number" label="Priority" min="1" required />

        <%= case @cta_form[:cta_type].value do %>
          <% "website" -> %>
            <.input
              field={@cta_form[:url]}
              label="Website URL"
              placeholder="https://example.com/checkout"
            />
          <% "phone" -> %>
            <.input field={@cta_form[:phone_number]} label="Phone number" placeholder="+254700000000" />
          <% "whatsapp" -> %>
            <.input
              field={@cta_form[:whatsapp_number]}
              label="WhatsApp number"
              placeholder="+254700000000"
            />
          <% "reply_buttons" -> %>
            <div class="space-y-4 rounded-lg border border-n300 bg-n200 p-4">
              <div>
                <h3 class="text-sm font-semibold text-n900">Reply button labels</h3>
                <p class="text-sm text-n400">Add up to three button labels.</p>
              </div>
              <.input
                :for={field_name <- RuleForm.button_fields()}
                field={@cta_form[field_name]}
                label={Phoenix.Naming.humanize(Atom.to_string(field_name))}
              />
            </div>
          <% "list_message" -> %>
            <div class="space-y-4 rounded-lg border border-n300 bg-n200 p-4">
              <div>
                <h3 class="text-sm font-semibold text-n900">List items</h3>
                <p class="text-sm text-n400">
                  Only rows with both a title and description are saved.
                </p>
              </div>
              <div
                :for={index <- RuleForm.list_item_indexes()}
                class="grid gap-3 rounded-lg border border-n300 bg-n50 p-4 sm:grid-cols-2"
              >
                <.input
                  field={@cta_form[String.to_atom("list_item_#{index}_title")]}
                  label={"Item #{index} title"}
                />
                <.input
                  field={@cta_form[String.to_atom("list_item_#{index}_description")]}
                  label={"Item #{index} description"}
                />
              </div>
            </div>
          <% "location" -> %>
            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@cta_form[:location_latitude]} type="number" step="any" label="Latitude" />
              <.input
                field={@cta_form[:location_longitude]}
                type="number"
                step="any"
                label="Longitude"
              />
            </div>
          <% "catalog" -> %>
            <.input field={@cta_form[:catalog_product_id]} label="Product ID" placeholder="sku_12345" />
          <% "custom" -> %>
            <.input
              field={@cta_form[:custom_template]}
              type="textarea"
              label="Custom template"
              placeholder="Share the showroom map and invite the buyer to pick a visit time."
            />
          <% _ -> %>
        <% end %>

        <:actions>
          <button
            type="button"
            phx-click="close_modal"
            class="inline-flex items-center justify-center rounded-lg border border-n300 bg-n50 px-4 py-2 text-sm font-medium text-n800 transition hover:bg-n200"
          >
            Cancel
          </button>
          <.button>{if @editing_rule, do: "Save changes", else: "Create rule"}</.button>
        </:actions>
      </.simple_form>
    </.modal_shell>
    """
  end

  attr :field, :map, required: true
  attr :values, :map, required: true

  defp custom_field(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <label class="block text-sm font-medium text-n900">{@field.label}</label>
      <%= case @field.field_type do %>
        <% "textarea" -> %>
          <textarea
            name={"item[metadata][#{@field.key}]"}
            class="min-h-[110px] w-full rounded-lg border border-n300 bg-n50 px-3 py-2 text-sm text-n900 shadow-sm outline-none transition focus:border-primary"
          ><%= Map.get(@values, @field.key, "") %></textarea>
        <% "boolean" -> %>
          <input type="hidden" name={"item[metadata][#{@field.key}]"} value="false" />
          <label class="inline-flex items-center gap-2 text-sm text-n400">
            <input
              type="checkbox"
              name={"item[metadata][#{@field.key}]"}
              value="true"
              checked={truthy?(Map.get(@values, @field.key))}
              class="h-4 w-4 rounded border-n300 text-primary focus:ring-primary"
            />
            <span>Enabled</span>
          </label>
        <% "number" -> %>
          <input
            type="number"
            step="any"
            name={"item[metadata][#{@field.key}]"}
            value={Map.get(@values, @field.key, "")}
            class="w-full rounded-lg border border-n300 bg-n50 px-3 py-2 text-sm text-n900 shadow-sm outline-none transition focus:border-primary"
          />
        <% type when type in ["url", "image_url"] -> %>
          <input
            type="url"
            name={"item[metadata][#{@field.key}]"}
            value={Map.get(@values, @field.key, "")}
            class="w-full rounded-lg border border-n300 bg-n50 px-3 py-2 text-sm text-n900 shadow-sm outline-none transition focus:border-primary"
          />
        <% _ -> %>
          <input
            type="text"
            name={"item[metadata][#{@field.key}]"}
            value={Map.get(@values, @field.key, "")}
            class="w-full rounded-lg border border-n300 bg-n50 px-3 py-2 text-sm text-n900 shadow-sm outline-none transition focus:border-primary"
          />
      <% end %>
      <p :if={@field.help_text} class="text-xs leading-5 text-n400">{@field.help_text}</p>
    </div>
    """
  end

  # ========================================================================
  # state loading
  # ========================================================================

  defp load_workspace(socket, workspace) do
    endpoint = Endpoints.get_endpoint(workspace.id) || default_endpoint(workspace.id)
    catalog = Catalogs.get_catalog(workspace.id) || default_catalog(workspace.id)
    cta_rules = CTARules.list_cta_rules(workspace.id)
    connection = Meta.get_connection_or_new(workspace.id)

    phone_number = Conversations.playground_phone_number(workspace.id)
    conversation = Conversations.get_conversation(workspace.id, phone_number, :playground)
    messages = if conversation, do: Conversations.list_messages(conversation.id), else: []

    socket
    |> assign(:workspace, workspace)
    |> assign(:endpoint, endpoint)
    |> assign(:catalog, catalog)
    |> assign(:cta_rules, sort_rules(cta_rules))
    |> assign(:connection, connection)
    |> assign(:selected_item, nil)
    |> assign(:selected_field, nil)
    |> assign(:item_values, %{})
    |> assign(:test_error, nil)
    |> assign(:data_ingestion_configured, data_ingestion_configured?(endpoint, catalog))
    |> assign(:cta_rules_configured, cta_rules != [])
    |> assign(:meta_configured, connection.status == "active")
    |> assign(:conversation, conversation)
    |> assign(:phone_number, phone_number)
    |> assign(:message_ids, message_ids(messages))
    |> assign_form(:business_form, Workspaces.change_workspace(workspace))
    |> assign_form(:endpoint_form, Endpoints.change_endpoint(endpoint))
    |> assign_form(:catalog_form, Catalogs.change_catalog(catalog))
    |> assign_form(:field_form, Catalogs.change_field(blank_field(catalog.id)))
    |> assign_form(:item_form, Catalogs.change_item(blank_item(catalog.id)))
    |> assign_form(:meta_form, Meta.change_connection(connection))
    |> assign_cta_form(RuleForm.changeset(RuleForm.blank(1)), RuleForm.blank(1))
    |> stream(:messages, messages, reset: true)
    |> reload_preview()
  end

  defp reload_products_state(socket, opts \\ []) do
    selected_item? = Keyword.get(opts, :clear_selected_item, true)
    workspace = socket.assigns.workspace
    catalog = Catalogs.get_catalog(workspace.id) || default_catalog(workspace.id)
    endpoint = Endpoints.get_endpoint(workspace.id) || socket.assigns.endpoint

    socket =
      socket
      |> assign(:catalog, catalog)
      |> assign(:endpoint, endpoint)
      |> assign(:data_ingestion_configured, data_ingestion_configured?(endpoint, catalog))
      |> assign_form(:catalog_form, Catalogs.change_catalog(catalog))
      |> assign_form(:field_form, Catalogs.change_field(blank_field(catalog.id)))

    socket =
      if selected_item? do
        socket
        |> assign(:selected_item, nil)
        |> assign(:item_values, %{})
        |> assign_form(:item_form, Catalogs.change_item(blank_item(catalog.id)))
      else
        item = socket.assigns.selected_item || blank_item(catalog.id)

        socket
        |> assign(:selected_item, item)
        |> assign(:item_values, item.metadata || %{})
        |> assign_form(:item_form, Catalogs.change_item(item))
      end

    reload_preview(socket)
  end

  defp reload_cta_state(socket) do
    cta_rules = CTARules.list_cta_rules(socket.assigns.workspace.id)
    next_priority = CTARules.next_priority(socket.assigns.workspace.id)
    rule_form = RuleForm.blank(next_priority)

    socket
    |> assign(:cta_rules, sort_rules(cta_rules))
    |> assign(:cta_rules_configured, cta_rules != [])
    |> assign(:active_modal, nil)
    |> assign(:editing_rule, nil)
    |> assign_cta_form(RuleForm.changeset(rule_form), rule_form)
  end

  defp persist_rule(socket, %RuleForm{} = rule_form) do
    attrs = RuleForm.to_cta_rule_attrs(rule_form)

    result =
      case socket.assigns.editing_rule do
        %CTARule{} = rule -> CTARules.update_cta_rule(rule, attrs)
        nil -> CTARules.create_cta_rule(socket.assigns.workspace.id, attrs)
      end

    case result do
      {:ok, _rule} ->
        flash = if socket.assigns.editing_rule, do: "CTA rule updated.", else: "CTA rule created."

        {:noreply,
         socket
         |> put_flash(:info, flash)
         |> reload_cta_state()}

      {:error, %Changeset{}} ->
        form_changeset =
          rule_form
          |> RuleForm.changeset()
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> put_flash(:error, "Could not save CTA rule. Please review the form and try again.")
         |> assign_cta_form(form_changeset, rule_form)}
    end
  end

  defp reload_preview(socket) do
    preview_data =
      Catalogs.build_workspace_context(
        socket.assigns.workspace.id,
        endpoint_cached_data(socket.assigns.endpoint),
        socket.assigns.workspace.data_source
      )

    socket
    |> assign(:preview_json, preview_json(preview_data))
    |> assign(:preview_label, "Current ingestion context")
  end

  defp regenerate_ai_context(socket) do
    case socket.assigns.workspace.data_source do
      "api" ->
        regenerate_live_api_context(socket)

      _ ->
        socket
        |> put_flash(:info, "AI context regenerated from the manual catalog.")
        |> reload_preview()
    end
  end

  defp regenerate_live_api_context(socket) do
    case socket.assigns.endpoint do
      %Endpoints.Endpoint{} = endpoint ->
        case Endpoints.refresh_cached_data(endpoint) do
          {:ok, refreshed_endpoint} ->
            socket
            |> assign(:endpoint, refreshed_endpoint)
            |> put_flash(:info, "AI context regenerated from the live JSON feed.")
            |> reload_preview()

          {:error, reason} ->
            put_flash(socket, :error, reason)
        end

      _ ->
        put_flash(socket, :error, "Save a JSON API endpoint before regenerating the AI context.")
    end
  end

  defp save_endpoint(socket, endpoint_params) do
    case Endpoints.upsert_endpoint(
           socket.assigns.workspace.id,
           Map.delete(endpoint_params, "action")
         ) do
      {:ok, endpoint} ->
        {:noreply,
         socket
         |> assign(:endpoint, endpoint)
         |> assign(
           :data_ingestion_configured,
           data_ingestion_configured?(endpoint, socket.assigns.catalog)
         )
         |> put_flash(:info, "Endpoint settings saved successfully.")
         |> reload_preview()
         |> assign_form(:endpoint_form, Endpoints.change_endpoint(endpoint))}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, :endpoint_form, Map.put(changeset, :action, :validate))}
    end
  end

  defp test_connection(socket, endpoint_params) do
    changeset =
      socket.assigns.endpoint
      |> current_endpoint(socket.assigns.workspace.id)
      |> Endpoints.change_endpoint(Map.delete(endpoint_params, "action"))
      |> Map.put(:action, :validate)

    case Ecto.Changeset.apply_action(changeset, :validate) do
      {:ok, endpoint} ->
        case Endpoints.fetch_live_data(endpoint) do
          {:ok, data} ->
            {:noreply,
             socket
             |> assign(:test_error, nil)
             |> assign(:preview_json, preview_json(data))
             |> assign(:preview_label, "Connection test preview")
             |> assign_form(:endpoint_form, changeset)
             |> put_flash(:info, "Connection successful.")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:test_error, reason)
             |> assign_form(:endpoint_form, changeset)}
        end

      {:error, %Changeset{} = invalid_changeset} ->
        {:noreply,
         assign_form(socket, :endpoint_form, Map.put(invalid_changeset, :action, :validate))}
    end
  end

  # ========================================================================
  # playground helpers
  # ========================================================================

  defp dispatch_message(socket, message) do
    trimmed_message = String.trim(message || "")

    cond do
      trimmed_message == "" ->
        {:noreply, socket}

      socket.assigns.assistant_pending ->
        {:noreply, socket}

      true ->
        case ensure_playground_conversation(socket) do
          {:ok, conversation, socket} ->
            dispatch_ref = System.unique_integer([:positive, :monotonic])
            workspace_id = socket.assigns.workspace.id
            phone_number = socket.assigns.phone_number
            pending_message = pending_user_message(trimmed_message, dispatch_ref)

            {:noreply,
             socket
             |> assign(:conversation, conversation)
             |> assign(:assistant_pending, true)
             |> assign(:active_dispatch_ref, dispatch_ref)
             |> assign(:pending_user_message, pending_message)
             |> assign_message_form("")
             |> start_async({:dispatch_message, dispatch_ref}, fn ->
               run_dispatch(workspace_id, phone_number, trimmed_message)
             end)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, format_error(reason))}
        end
    end
  end

  defp fail_dispatch(socket, dispatch_ref, reason) do
    if socket.assigns.active_dispatch_ref == dispatch_ref do
      socket
      |> assign(:pending_user_message, nil)
      |> assign(:assistant_pending, false)
      |> assign(:active_dispatch_ref, nil)
      |> put_flash(:error, format_error(reason))
    else
      socket
    end
  end

  defp fail_recommend(socket, ref, reason) do
    if socket.assigns.recommend_ref == ref do
      socket
      |> assign(:recommending, false)
      |> assign(:recommend_ref, nil)
      |> put_flash(:error, format_error(reason))
    else
      socket
    end
  end

  defp reset_playground(socket) do
    socket
    |> assign(:conversation, nil)
    |> assign(:message_ids, MapSet.new())
    |> assign(:pending_user_message, nil)
    |> assign(:assistant_pending, false)
    |> assign(:active_dispatch_ref, nil)
    |> assign_message_form("")
    |> stream(:messages, [], reset: true)
  end

  defp maybe_subscribe(socket, workspace_id) do
    if connected?(socket) and socket.assigns.subscribed_workspace_id != workspace_id do
      Conversations.subscribe_playground(workspace_id)
      Endpoints.subscribe_workspace(workspace_id)
      assign(socket, :subscribed_workspace_id, workspace_id)
    else
      socket
    end
  end

  defp ensure_playground_conversation(socket) do
    case socket.assigns.conversation do
      nil ->
        case Conversations.get_or_create_conversation(
               socket.assigns.workspace.id,
               socket.assigns.phone_number,
               :playground
             ) do
          {:ok, conversation} -> {:ok, conversation, assign(socket, :conversation, conversation)}
          {:error, reason} -> {:error, reason}
        end

      conversation ->
        {:ok, conversation, socket}
    end
  end

  defp run_dispatch(workspace_id, phone_number, message) do
    with {:ok, prepared} <- Dispatcher.prepare_dispatch(workspace_id),
         {:ok, _assistant_message} <-
           Dispatcher.dispatch_prepared(prepared, phone_number, message, :playground) do
      {:ok, %{prepared: prepared}}
    end
  end

  defp stream_new_messages(socket, messages) do
    Enum.reduce(messages, socket, fn message, acc ->
      acc
      |> update(:message_ids, &MapSet.put(&1, message.id))
      |> stream_insert(:messages, message)
    end)
  end

  defp reconcile_pending_state(socket, %Message{role: "user", content: content}) do
    case socket.assigns.pending_user_message do
      %{content: ^content} -> assign(socket, :pending_user_message, nil)
      _pending -> socket
    end
  end

  defp reconcile_pending_state(socket, %Message{role: "assistant"}) do
    assign(socket, :assistant_pending, false)
  end

  defp reconcile_pending_state(socket, _message), do: socket

  defp assign_message_form(socket, value) do
    assign(socket, :message_form, to_form(%{"message" => value}, as: :playground))
  end

  defp pending_user_message(content, dispatch_ref) do
    %{
      id: "pending-user-#{dispatch_ref}",
      role: "user",
      content: content,
      inserted_at: DateTime.utc_now()
    }
  end

  defp message_ids(messages) do
    messages
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  defp format_error(%Ecto.Changeset{}),
    do: "The chat could not be saved. Please review your setup and try again."

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  # ========================================================================
  # misc helpers
  # ========================================================================

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp assign_form(socket, key, %Changeset{} = changeset) do
    assign(socket, key, to_form(changeset, as: form_name(key)))
  end

  defp assign_cta_form(socket, %Changeset{} = changeset, %RuleForm{} = rule_form) do
    socket
    |> assign(:rule_form_data, rule_form)
    |> assign(:cta_form, to_form(changeset, as: :cta_rule_form))
  end

  defp form_name(:business_form), do: :workspace
  defp form_name(:endpoint_form), do: :endpoint
  defp form_name(:catalog_form), do: :catalog
  defp form_name(:field_form), do: :field
  defp form_name(:item_form), do: :item
  defp form_name(:meta_form), do: :connection

  defp to_step("business"), do: :business
  defp to_step("products"), do: :products
  defp to_step("cta"), do: :cta
  defp to_step("meta"), do: :meta
  defp to_step(_), do: :business

  defp step_index(step), do: Enum.find_index(@steps, &(&1 == step)) + 1

  defp step_offset(step, offset) do
    index = Enum.find_index(@steps, &(&1 == step)) + offset
    Enum.at(@steps, max(0, min(index, length(@steps) - 1)))
  end

  defp step_caption(:business), do: "Describing your business"
  defp step_caption(:products), do: "Configuring product data"
  defp step_caption(:cta), do: "Configuring interaction CTAs"
  defp step_caption(:meta), do: "Securing the live connection"

  defp next_label(:business), do: "Next: Products"
  defp next_label(:products), do: "Next: CTA Rules"
  defp next_label(:cta), do: "Next: Meta Connection"
  defp next_label(_), do: "Next"

  defp custom_fields(nil), do: []

  defp custom_fields(catalog) do
    Enum.reject(catalog.fields || [], fn field -> field.key in Catalogs.canonical_item_keys() end)
  end

  defp consume_item_image_upload(socket, catalog_id) do
    consume_uploaded_entries(socket, :item_image, fn %{path: path}, entry ->
      extension = Path.extname(entry.client_name || "")
      filename = "#{System.unique_integer([:positive])}#{extension}"
      relative_path = Path.join(["uploads", "catalogs", to_string(catalog_id), filename])
      destination = Path.join(Application.app_dir(:sokochat, "priv/static"), relative_path)

      File.mkdir_p!(Path.dirname(destination))
      File.cp!(path, destination)
      {:ok, "/" <> relative_path}
    end)
    |> List.first()
  end

  defp clear_item_uploads(socket) do
    {socket, _uploads} = Phoenix.LiveView.Upload.maybe_cancel_uploads(socket)
    socket
  end

  defp sort_rules(rules) do
    Enum.sort_by(rules, &{&1.priority || 0, &1.id})
  end

  defp current_endpoint(nil, workspace_id), do: default_endpoint(workspace_id)
  defp current_endpoint(endpoint, _workspace_id), do: endpoint

  defp current_field(nil, catalog_id), do: blank_field(catalog_id)
  defp current_field(field, _catalog_id), do: field

  defp current_item(nil, catalog_id), do: blank_item(catalog_id)
  defp current_item(item, _catalog_id), do: item

  defp default_endpoint(workspace_id) do
    %Endpoints.Endpoint{
      workspace_id: workspace_id,
      method: "GET",
      refresh_strategy: "on_demand",
      headers: %{}
    }
  end

  defp default_catalog(workspace_id) do
    %Catalog{
      workspace_id: workspace_id,
      name: "Product catalog",
      entity_label: "item",
      context_notes: "",
      fields: [],
      items: []
    }
  end

  defp blank_field(catalog_id) do
    %Field{catalog_id: catalog_id, field_type: "text", required: false, position: 0}
  end

  defp blank_item(catalog_id) do
    %Item{catalog_id: catalog_id, source: "manual", status: "active", metadata: %{}}
  end

  defp endpoint_cached_data(%{cached_data: cached_data}), do: cached_data
  defp endpoint_cached_data(_), do: nil

  defp preview_json(nil), do: nil
  defp preview_json(data), do: Jason.encode_to_iodata!(data, pretty: true)

  defp last_fetched_label(nil), do: nil

  defp last_fetched_label(%DateTime{} = last_fetched_at) do
    minutes_ago = max(DateTime.diff(DateTime.utc_now(), last_fetched_at, :minute), 0)

    cond do
      minutes_ago < 1 -> "just now"
      minutes_ago == 1 -> "1 minute ago"
      minutes_ago < 60 -> "#{minutes_ago} minutes ago"
      minutes_ago < 1_440 -> "#{div(minutes_ago, 60)} hours ago"
      true -> "#{div(minutes_ago, 1_440)} days ago"
    end
  end

  defp normalize_id(id) when is_binary(id), do: String.to_integer(id)
  defp normalize_id(id), do: id

  defp truthy?(value), do: value in [true, "true", "1", 1, "on"]

  defp data_ingestion_configured?(endpoint, catalog) do
    endpoint_configured?(endpoint) or catalog_configured?(catalog)
  end

  defp endpoint_configured?(%{url: url}) when is_binary(url), do: String.trim(url) != ""
  defp endpoint_configured?(_), do: false

  defp catalog_configured?(%{id: id}) when not is_nil(id), do: true
  defp catalog_configured?(_), do: false

  defp endpoint_label(nil), do: "not configured"
  defp endpoint_label(%{url: nil}), do: "not configured"
  defp endpoint_label(%{url: url}), do: URI.parse(url).host || url
  defp endpoint_label(_), do: "not configured"

  # --- cta presentation ---------------------------------------------------

  defp suggestion_summary(%{"cta_type" => cta_type, "cta_payload" => payload}) do
    payload_summary(%CTARule{cta_type: cta_type, cta_payload: payload})
  end

  defp payload_summary(%CTARule{cta_type: "website", cta_payload: %{"url" => url}}), do: url

  defp payload_summary(%CTARule{cta_type: "phone", cta_payload: %{"number" => number}}),
    do: number

  defp payload_summary(%CTARule{cta_type: "whatsapp", cta_payload: %{"number" => number}}),
    do: number

  defp payload_summary(%CTARule{cta_type: "reply_buttons", cta_payload: %{"buttons" => buttons}})
       when is_list(buttons),
       do: Enum.join(buttons, ", ")

  defp payload_summary(%CTARule{cta_type: "list_message", cta_payload: %{"items" => items}})
       when is_list(items),
       do: "#{length(items)} items"

  defp payload_summary(%CTARule{
         cta_type: "location",
         cta_payload: %{"latitude" => latitude, "longitude" => longitude}
       }),
       do: "#{latitude}, #{longitude}"

  defp payload_summary(%CTARule{cta_type: "catalog", cta_payload: %{"product_id" => product_id}}),
    do: product_id

  defp payload_summary(%CTARule{cta_type: "custom", cta_payload: %{"template" => template}}),
    do: template

  defp payload_summary(%CTARule{}), do: "Payload configured"

  defp humanize_cta_type("reply_buttons"), do: "Reply buttons"
  defp humanize_cta_type("list_message"), do: "List message"
  defp humanize_cta_type("website"), do: "Website"
  defp humanize_cta_type("whatsapp"), do: "WhatsApp"
  defp humanize_cta_type("phone"), do: "Phone"
  defp humanize_cta_type("location"), do: "Location"
  defp humanize_cta_type("catalog"), do: "Catalog"
  defp humanize_cta_type("custom"), do: "Custom"
  defp humanize_cta_type(type), do: Phoenix.Naming.humanize(type)

  defp cta_icon("website"), do: "hero-globe-alt-mini"
  defp cta_icon("phone"), do: "hero-phone-mini"
  defp cta_icon("whatsapp"), do: "hero-chat-bubble-left-right-mini"
  defp cta_icon("reply_buttons"), do: "hero-cursor-arrow-rays-mini"
  defp cta_icon("list_message"), do: "hero-list-bullet-mini"
  defp cta_icon("location"), do: "hero-map-pin-mini"
  defp cta_icon("catalog"), do: "hero-squares-2x2-mini"
  defp cta_icon(_), do: "hero-bolt-mini"

  # --- meta presentation --------------------------------------------------

  defp persisted?(%{id: id}) when not is_nil(id), do: true
  defp persisted?(_), do: false

  defp webhook_url(socket, slug), do: url(socket, ~p"/webhooks/whatsapp/#{slug}")

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

  defp alert_classes(:info), do: "border-[#BFD7FF] border-l-[#2F6FED] bg-[#F4F8FF] text-[#23448E]"
  defp alert_classes(:success), do: "border-[#B7EBCF] border-l-primary bg-[#E8FFF3] text-primary"

  defp alert_icon(:warning), do: "hero-exclamation-triangle-mini"
  defp alert_icon(:info), do: "hero-information-circle-mini"
  defp alert_icon(:success), do: "hero-check-circle-mini"
end
