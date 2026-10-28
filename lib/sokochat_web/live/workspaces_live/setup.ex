defmodule SokochatWeb.WorkspacesLive.Setup do
  @moduledoc """
  Unified workspace setup. Business, products, CTA rules, and Meta each
  live on their own page inside the workspace shell. The WhatsApp playground
  and analytics are separate tabs.
  """
  use SokochatWeb, :live_view

  import SokochatWeb.WorkspaceShell

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

  @variant_slots 4

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workspace")
     |> assign(:workspace, nil)
     |> assign(:active_step, :business)
     |> assign(:active_tab, "manual")
     |> assign(:active_modal, nil)
     |> assign(:lang, "EN")
     |> assign(:variant_drafts, empty_variant_slots())
     |> assign(:category_draft, "")
     |> assign(:category_query, "")
     |> assign(:details_open, false)
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
     # playground leftovers kept so existing message handlers still compile
     |> assign(:conversation, nil)
     |> assign(:phone_number, nil)
     |> assign(:subscribed_workspace_id, nil)
     |> assign(:message_ids, MapSet.new())
     |> assign(:pending_user_message, nil)
     |> assign(:assistant_pending, false)
     |> assign(:active_dispatch_ref, nil)
     |> assign_message_form("")
     |> stream(:messages, [])
     |> allow_upload(:cover,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 8_000_000
     )
     |> allow_upload(:extras,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 4,
       max_file_size: 8_000_000
     ), layout: false}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> maybe_subscribe(workspace.id)
         |> load_workspace(workspace)
         |> assign(:active_step, step_from_action(socket.assigns.live_action))
         |> assign(:page_title, step_title(socket.assigns.live_action))}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  defp step_from_action(action) when action in [:business, :products, :cta, :meta], do: action
  defp step_from_action(_action), do: :business

  defp step_title(:products), do: "Products"
  defp step_title(:cta), do: "CTA Rules"
  defp step_title(:meta), do: "Meta"
  defp step_title(_), do: "Business"

  @impl true
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

  def handle_event("filter_categories", %{"category" => %{"query" => query}}, socket) do
    {:noreply, assign(socket, :category_query, query)}
  end

  def handle_event("add_category", %{"name" => name}, socket) do
    add_shop_category(socket, name)
  end

  def handle_event("add_category", %{"category" => %{"query" => query}}, socket) do
    add_shop_category(socket, query)
  end

  def handle_event("remove_category", %{"name" => name}, socket) do
    case Catalogs.remove_category(socket.assigns.catalog, name) do
      {:ok, _catalog} ->
        {:noreply, reload_products_state(socket, clear_selected_item: false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not remove that category.")}
    end
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

    drafts = drafts_from(item_params["variants"])

    values =
      case item_params["metadata"] do
        metadata when is_map(metadata) -> metadata
        _ -> socket.assigns.item_values
      end

    {:noreply,
     socket
     |> assign(:variant_drafts, drafts)
     |> assign(:category_draft, item_params["category"] || "")
     |> assign(:item_values, values)
     |> assign(
       :details_open,
       socket.assigns.details_open or product_basics?(item_params["title"], drafts)
     )
     |> assign_form(:item_form, changeset)}
  end

  def handle_event("save_item", %{"item" => item_params}, socket) do
    variants = parse_variants(item_params["variants"])
    existing = socket.assigns.selected_item

    cond do
      variants == [] ->
        {:noreply,
         put_flash(socket, :error, "Add at least one variant with a name and a KES price.")}

      is_nil(Catalogs.normalize_category_name(item_params["category"])) ->
        {:noreply, put_flash(socket, :error, "Pick a category.")}

      true ->
        case store_product_images(socket, socket.assigns.catalog.id, existing) do
          {:ok, socket, cover, extras} ->
            metadata =
              ((existing && existing.metadata) || %{})
              |> Map.put("variants", variants)
              |> Map.put("images", extras)
              |> Map.put("category", blank_to_nil(item_params["category"]))
              |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
              |> Map.new()

            attrs = %{
              "id" => item_params["id"],
              "title" => item_params["title"],
              "description" => item_params["description"],
              "currency" => "KES",
              "price" => variant_floor(variants),
              "image_url" => cover,
              "status" => item_params["status"] || "active",
              "source" => "manual",
              "metadata" => metadata
            }

            case Catalogs.upsert_item(socket.assigns.catalog, attrs) do
              {:ok, _item} ->
                {:noreply,
                 socket
                 |> clear_item_uploads()
                 |> put_flash(:info, "Product saved.")
                 |> assign(:active_modal, nil)
                 |> reload_products_state()}

              {:error, %Changeset{} = changeset} ->
                {:noreply,
                 assign_form(socket, :item_form, Map.put(changeset, :action, :validate))}
            end

          {:error, socket, message} ->
            {:noreply, put_flash(socket, :error, message)}
        end
    end
  end

  def handle_event("add_variant", _params, socket) do
    drafts = socket.assigns.variant_drafts

    drafts =
      if length(drafts) < @variant_slots do
        drafts ++ [%{"label" => "", "price" => ""}]
      else
        drafts
      end

    {:noreply, assign(socket, :variant_drafts, drafts)}
  end

  def handle_event("remove_variant", %{"index" => index}, socket) do
    index = String.to_integer(index)
    drafts = List.delete_at(socket.assigns.variant_drafts, index)
    drafts = if drafts == [], do: empty_variant_slots(), else: drafts

    {:noreply, assign(socket, :variant_drafts, drafts)}
  end

  def handle_event("new_item", _params, socket) do
    categories = Catalogs.shop_categories(socket.assigns.catalog)

    {:noreply,
     socket
     |> clear_item_uploads()
     |> assign(:selected_item, nil)
     |> assign(:item_values, %{})
     |> assign(:variant_drafts, empty_variant_slots())
     |> assign(:category_draft, if(match?([_], categories), do: hd(categories), else: ""))
     |> assign(:details_open, false)
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
     |> assign(:variant_drafts, slots_from_item(item))
     |> assign(:details_open, product_basics?(item.title, slots_from_item(item)))
     |> assign(:category_draft, category_of(item))
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
    assigns = assign(assigns, :custom_fields, custom_fields(assigns[:catalog]))

    ~H"""
    <.shell
      :if={@workspace}
      workspace={@workspace}
      current_user={@current_user}
      tab={@active_step}
      title={@page_title}
      flash={@flash}
    >
      <div class="mx-auto w-full max-w-5xl">
        <div class="rounded-lg border border-n100 bg-n50 p-6 shadow-[0_8px_24px_rgba(0,0,0,0.04)] lg:p-8">
          <.business_step :if={@active_step == :business} {assigns} />
          <.products_step :if={@active_step == :products} {assigns} />
          <.cta_step :if={@active_step == :cta} {assigns} />
          <.meta_step :if={@active_step == :meta} {assigns} />
        </div>
      </div>

      <.catalog_model_modal :if={@active_modal == :model} {assigns} />
      <.field_modal :if={@active_modal == :field} {assigns} />
      <.item_modal :if={@active_modal == :item} {assigns} />
      <.cta_rule_modal :if={@active_modal == :cta_rule} {assigns} />
    </.shell>
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
          <.button disabled={business_unchanged?(@business_form)}>
            Save business profile
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  # --- step 2: products ---------------------------------------------------

  defp products_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h3 class="text-xl font-semibold text-n900">Products</h3>
          <p class="mt-1 text-sm text-n400">
            Set the categories you sell first, then add products. Each product picks one category, needs a cover image, and at least one variant priced in KES.
          </p>
        </div>
        <.button :if={@catalog.id} type="button" phx-click="new_item">
          <.icon name="hero-plus" class="h-4 w-4" /> Add product
        </.button>
      </div>

      <div class="space-y-6">
        <.source_banner source="manual" active={@workspace.data_source} />
        <div :if={!@catalog.id} class="space-y-6">
          <.empty_state
            icon="hero-squares-2x2"
            title="Set up your catalog model"
            body="Define a reusable schema for this shop, then add fields and items one by one without touching JSON."
          >
            <.button type="button" phx-click="open_model">
              <.icon name="hero-sparkles-mini" class="h-4 w-4" /> Set up catalog model
            </.button>
          </.empty_state>
        </div>

        <div :if={@catalog.id} class="space-y-6">
          <.categories_panel categories={Catalogs.shop_categories(@catalog)} query={@category_query} />

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
                :for={field <- custom_fields(@catalog)}
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
              <span :if={@custom_fields == []} class="text-xs text-n400">
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
                Category
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
                  <p class="truncate font-mono text-xs text-n400">{variant_summary(item)}</p>
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
            <.button type="submit" name="endpoint[action]" value="test" variant="secondary">
              Test connection
            </.button>
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

  attr :categories, :list, required: true
  attr :query, :string, required: true

  defp categories_panel(assigns) do
    assigns =
      assign(
        assigns,
        :suggestions,
        Catalogs.filter_suggested_categories(assigns.query, assigns.categories)
      )

    ~H"""
    <div class="rounded-lg border border-n300 bg-n50 p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-wider text-n400">Categories</p>
          <p class="mt-1 text-sm text-n500">
            Choose what you sell. Products pick from this list once.
          </p>
        </div>
      </div>

      <form
        id="shop-categories"
        phx-change="filter_categories"
        phx-submit="add_category"
        class="mt-3 flex gap-2"
      >
        <div class="relative min-w-0 flex-1">
          <input
            type="search"
            name="category[query]"
            value={@query}
            autocomplete="off"
            placeholder="Search or type a category"
            class="block w-full rounded-lg border border-n300 bg-n50 px-3.5 py-2.5 text-[15px] text-n900 shadow-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/15"
          />
          <div
            :if={String.trim(@query) != "" and @suggestions != []}
            class="absolute z-20 mt-1 max-h-56 w-full overflow-y-auto rounded-lg border border-n300 bg-white py-1 shadow-[0_8px_24px_rgba(0,0,0,0.08)]"
          >
            <button
              :for={name <- @suggestions}
              type="button"
              phx-click="add_category"
              phx-value-name={name}
              class="block w-full px-3.5 py-2 text-left text-sm text-n900 hover:bg-n100"
            >
              {name}
            </button>
          </div>
        </div>
        <.button type="submit" variant="secondary">Add</.button>
      </form>

      <div class="mt-3 flex flex-wrap gap-2">
        <span
          :for={name <- @categories}
          class="inline-flex items-center gap-1.5 rounded-full border border-n300 bg-n100 px-3 py-1 text-xs font-medium text-n800"
        >
          {name}
          <button
            type="button"
            phx-click="remove_category"
            phx-value-name={name}
            aria-label={"Remove #{name}"}
            class="text-n400 hover:text-red-600"
          >
            <.icon name="hero-x-mark-mini" class="h-3.5 w-3.5" />
          </button>
        </span>
        <span :if={@categories == []} class="text-xs text-n400">
          No categories yet. Search the list or type your own, then add.
        </span>
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
          <.button type="button" phx-click="open_add_rule">
            <.icon name="hero-plus-mini" class="h-4 w-4" /> Add rule
          </.button>
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
          <.button type="button" variant="secondary" phx-click="open_add_rule">
            <.icon name="hero-plus-mini" class="h-4 w-4" /> Add manually
          </.button>
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
    <.button type="button" variant={@variant} phx-click="recommend_ctas" disabled={@recommending}>
      <.icon
        name={if @recommending, do: "hero-arrow-path-mini", else: "hero-sparkles-mini"}
        class={"h-4 w-4 #{if @recommending, do: "animate-spin"}"}
      />
      {if @recommending, do: "Generating...", else: "Recommend based on my product"}
    </.button>
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
      <.button type="button" size="sm" phx-click="set_data_source" phx-value-source={@source}>
        <.icon name="hero-bolt-mini" class="h-3.5 w-3.5" /> Set as AI source
      </.button>
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
      <div class="fixed inset-0 flex items-center justify-center p-4 sm:p-6">
        <div class={[
          "relative flex max-h-[calc(100dvh-48px)] w-full flex-col overflow-hidden rounded-2xl border border-n300 bg-white shadow-[0_20px_60px_rgba(0,0,0,0.18)]",
          @width
        ]}>
          <div class="flex shrink-0 items-start justify-between gap-4 border-b border-n300 px-6 py-4">
            <div class="min-w-0 space-y-1">
              <h2 class="text-lg font-semibold text-n900">{@title}</h2>
              <p :if={@subtitle} class="text-sm leading-6 text-n400">{@subtitle}</p>
            </div>
            <.button
              type="button"
              variant="ghost"
              size="icon"
              phx-click="close_modal"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="h-4 w-4" />
            </.button>
          </div>
          <div class="min-h-0 flex-1 overflow-y-auto px-6 py-5">{render_slot(@inner_block)}</div>
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
          <.button type="button" variant="secondary" phx-click="close_modal">
            Cancel
          </.button>
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
          <.button type="button" variant="secondary" phx-click="close_modal">
            Cancel
          </.button>
          <.button>{if @selected_field, do: "Update field", else: "Add field"}</.button>
        </:actions>
      </.simple_form>
    </.modal_shell>
    """
  end

  defp item_modal(assigns) do
    assigns = assign(assigns, :can_save, product_can_save?(assigns))

    ~H"""
    <.modal_shell
      width="max-w-2xl"
      title={if @selected_item, do: "Edit product", else: "New product"}
      subtitle="Name, one cover image, and variant prices in KES. Extra images are optional."
    >
      <.form
        for={@item_form}
        phx-change="validate_item"
        phx-submit="save_item"
        phx-debounce="200"
        multipart
        class="space-y-5"
      >
        <input type="hidden" name="item[id]" value={(@selected_item && @selected_item.id) || ""} />
        <input type="hidden" name="item[status]" value="active" />
        <.input field={@item_form[:title]} label="Name" required />
        <.input field={@item_form[:description]} type="textarea" label="Description" rows="3" />
        <div>
          <label class="block text-[13px] font-semibold leading-6 text-n900">
            Category<span class="text-danger" aria-hidden="true"> *</span>
          </label>
          <select
            name="item[category]"
            required
            class="mt-1.5 block w-full rounded-lg border border-n300 bg-n50 px-3.5 py-2.5 text-[15px] text-n900 shadow-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/15"
          >
            <option value="">Select a category</option>
            <option
              :for={name <- category_options(@catalog, @category_draft)}
              value={name}
              selected={name == @category_draft}
            >
              {name}
            </option>
          </select>
          <p :if={Catalogs.shop_categories(@catalog) == []} class="mt-1.5 text-xs leading-5 text-n400">
            Add categories on the Products page first.
          </p>
        </div>

        <div class="space-y-3">
          <div class="flex items-center justify-between gap-3">
            <div>
              <h3 class="text-sm font-semibold text-n900">
                Variants<span class="text-danger" aria-hidden="true"> *</span>
              </h3>
              <p class="text-xs leading-5 text-n400">At least one. Prices are in KES.</p>
            </div>
            <.button
              type="button"
              variant="secondary"
              size="sm"
              phx-click="add_variant"
              disabled={length(@variant_drafts) >= 4}
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Add variant
            </.button>
          </div>
          <div :for={{slot, index} <- Enum.with_index(@variant_drafts)} class="flex items-end gap-2">
            <input type="hidden" name={"item[variants][#{index}][slot]"} value={index} />
            <div class="min-w-0 flex-1">
              <label class="block text-[13px] font-semibold leading-6 text-n900">
                Name<span class="text-danger" aria-hidden="true"> *</span>
              </label>
              <input
                type="text"
                name={"item[variants][#{index}][label]"}
                value={slot["label"]}
                aria-required="true"
                class="mt-1.5 block w-full rounded-lg border border-n300 bg-n50 px-3.5 py-2.5 text-[15px] text-n900 shadow-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/15"
              />
            </div>
            <div class="w-32 shrink-0">
              <label class="block text-[13px] font-semibold leading-6 text-n900">
                KES<span class="text-danger" aria-hidden="true"> *</span>
              </label>
              <input
                type="number"
                min="0"
                step="1"
                name={"item[variants][#{index}][price]"}
                value={slot["price"]}
                aria-required="true"
                class="mt-1.5 block w-full rounded-lg border border-n300 bg-n50 px-3.5 py-2.5 text-[15px] text-n900 shadow-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/15"
              />
            </div>
            <.button
              type="button"
              variant="ghost"
              size="icon"
              phx-click="remove_variant"
              phx-value-index={index}
              disabled={length(@variant_drafts) == 1}
              aria-label="Remove variant"
            >
              <.icon name="hero-x-mark" class="h-4 w-4" />
            </.button>
          </div>
        </div>

        <div :if={@details_open} class="form-reveal space-y-5">
          <div class="grid gap-4 sm:grid-cols-2">
            <div class="space-y-2">
              <h3 class="text-sm font-semibold text-n900">
                Cover image<span class="text-danger" aria-hidden="true"> *</span>
              </h3>
              <p class="text-xs leading-5 text-n400">JPG, PNG, or WEBP.</p>
              <img
                :if={@selected_item && @selected_item.image_url}
                src={@selected_item.image_url}
                alt=""
                class="h-16 w-16 rounded-lg object-cover"
              />
              <.live_file_input upload={@uploads.cover} class={file_input_class()} />
            </div>
            <div class="space-y-2">
              <h3 class="text-sm font-semibold text-n900">Extra images</h3>
              <p class="text-xs leading-5 text-n400">Optional. Up to four.</p>
              <div :if={extra_images(@selected_item) != []} class="flex flex-wrap gap-2">
                <img
                  :for={url <- extra_images(@selected_item)}
                  src={url}
                  alt=""
                  class="h-16 w-16 rounded-lg object-cover"
                />
              </div>
              <.live_file_input upload={@uploads.extras} class={file_input_class()} />
            </div>
          </div>

          <div :if={@custom_fields != []} class="space-y-3">
            <div>
              <h3 class="text-sm font-semibold text-n900">Custom fields</h3>
              <p class="text-xs leading-5 text-n400">
                Stored with the product and included in replies.
              </p>
            </div>
            <div class="grid gap-4 sm:grid-cols-2">
              <.custom_field :for={field <- @custom_fields} field={field} values={@item_values} />
            </div>
          </div>
        </div>

        <div class="-mx-6 -mb-5 flex items-center justify-end gap-2 border-t border-n300 px-6 py-4">
          <.button type="button" variant="secondary" phx-click="close_modal">Cancel</.button>
          <.button disabled={not @can_save}>
            {if @selected_item, do: "Update product", else: "Add product"}
          </.button>
        </div>
      </.form>
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
          <.button type="button" variant="secondary" phx-click="close_modal">
            Cancel
          </.button>
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
      <label class="block text-sm font-medium text-n900">
        {@field.label}<span :if={@field.required} class="text-danger" aria-hidden="true"> *</span>
      </label>
      <%= case @field.field_type do %>
        <% "textarea" -> %>
          <textarea
            name={"item[metadata][#{@field.key}]"}
            required={@field.required}
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
            required={@field.required}
            class="w-full rounded-lg border border-n300 bg-n50 px-3 py-2 text-sm text-n900 shadow-sm outline-none transition focus:border-primary"
          />
        <% type when type in ["url", "image_url"] -> %>
          <input
            type="url"
            name={"item[metadata][#{@field.key}]"}
            value={Map.get(@values, @field.key, "")}
            required={@field.required}
            class="w-full rounded-lg border border-n300 bg-n50 px-3 py-2 text-sm text-n900 shadow-sm outline-none transition focus:border-primary"
          />
        <% _ -> %>
          <input
            type="text"
            name={"item[metadata][#{@field.key}]"}
            value={Map.get(@values, @field.key, "")}
            required={@field.required}
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
    catalog = ensure_catalog(workspace)
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

  defp business_unchanged?(%{source: %Ecto.Changeset{changes: changes}}), do: changes == %{}
  defp business_unchanged?(_form), do: true

  defp custom_fields(nil), do: []

  defp custom_fields(catalog) do
    hidden = Catalogs.canonical_item_keys() ++ Catalogs.reserved_item_keys()
    Enum.reject(catalog.fields || [], fn field -> field.key in hidden end)
  end

  defp store_product_images(socket, catalog_id, existing) do
    with {:ok, covers} <- consume_images(socket, :cover, catalog_id),
         {:ok, extras} <- consume_images(socket, :extras, catalog_id) do
      cover =
        case covers do
          [url | _] -> url
          [] -> existing && existing.image_url
        end

      extra_urls =
        case extras do
          [] -> extra_images(existing)
          urls -> urls
        end

      if is_binary(cover) and cover != "" do
        {:ok, socket, cover, extra_urls}
      else
        {:error, socket, "Add a cover image."}
      end
    else
      {:error, message} -> {:error, socket, message}
    end
  end

  defp consume_images(socket, name, catalog_id) do
    results =
      consume_uploaded_entries(socket, name, fn %{path: path}, entry ->
        extension = Path.extname(entry.client_name || "") |> String.downcase()
        key = "catalogs/#{catalog_id}/#{System.unique_integer([:positive])}#{extension}"

        case Sokochat.Storage.Images.put_file(path, key, entry.client_type) do
          {:ok, url} -> {:ok, url}
          {:error, reason} -> {:postpone, {:error, image_error(reason)}}
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, message} -> {:error, message}
      nil -> {:ok, results}
    end
  rescue
    ArgumentError ->
      {:error, "Wait for the image upload to finish, then save again."}
  end

  defp image_error(reason) when is_binary(reason), do: reason

  defp empty_variant_slots, do: [%{"label" => "", "price" => ""}]

  defp product_can_save?(assigns) do
    product_basics?(assigns.item_form[:title].value, assigns.variant_drafts) and
      cover_ready?(assigns) and
      category_ready?(assigns) and
      required_fields_filled?(assigns.custom_fields, assigns.item_values)
  end

  defp category_ready?(assigns) do
    name = Catalogs.normalize_category_name(assigns.category_draft)
    name != nil and name in category_options(assigns.catalog, assigns.category_draft)
  end

  defp category_options(catalog, draft) do
    names = Catalogs.shop_categories(catalog)

    cond do
      draft in [nil, ""] -> names
      draft in names -> names
      true -> names ++ [draft]
    end
  end

  defp product_basics?(title, drafts) when is_binary(title) do
    String.trim(title) != "" and Enum.any?(drafts, &complete_variant?/1)
  end

  defp product_basics?(_title, _drafts), do: false

  defp complete_variant?(%{"label" => label, "price" => price}) do
    String.trim(to_string(label || "")) != "" and is_number(parse_price(price))
  end

  defp complete_variant?(_slot), do: false

  defp cover_ready?(assigns) do
    existing =
      case assigns.selected_item do
        %{image_url: url} when is_binary(url) and url != "" -> true
        _ -> false
      end

    existing or assigns.uploads.cover.entries != []
  end

  defp required_fields_filled?(fields, values) do
    Enum.all?(fields || [], fn field ->
      not field.required or custom_filled?(field, values || %{})
    end)
  end

  defp custom_filled?(%{field_type: "boolean"} = field, values) do
    truthy?(Map.get(values, field.key))
  end

  defp custom_filled?(field, values) do
    values |> Map.get(field.key) |> to_string() |> String.trim() != ""
  end

  defp file_input_class do
    "block w-full text-sm text-n500 file:mr-3 file:inline-flex file:h-8 file:cursor-pointer file:items-center file:rounded-md file:border-0 file:bg-[#efefef] file:px-2.5 file:text-sm file:font-medium file:text-[#161616]"
  end

  defp slots_from_item(item) do
    existing =
      item
      |> variants_of()
      |> Enum.map(fn variant ->
        %{"label" => variant["label"] || "", "price" => format_kes(variant["price"])}
      end)
      |> Enum.take(@variant_slots)

    if existing == [], do: empty_variant_slots(), else: existing
  end

  defp drafts_from(nil), do: empty_variant_slots()

  defp drafts_from(variants) when is_map(variants) do
    parsed =
      variants
      |> Enum.sort_by(fn {key, _} ->
        case Integer.parse(to_string(key)) do
          {number, _} -> number
          :error -> 0
        end
      end)
      |> Enum.map(fn {_key, row} ->
        %{"label" => row["label"] || "", "price" => row["price"] || ""}
      end)
      |> Enum.take(@variant_slots)

    if parsed == [], do: empty_variant_slots(), else: parsed
  end

  defp parse_variants(variants) do
    drafts_from(variants)
    |> Enum.map(fn slot ->
      label = String.trim(slot["label"] || "")
      price = parse_price(slot["price"])
      if label == "" or is_nil(price), do: nil, else: %{"label" => label, "price" => price}
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_price(value) when is_integer(value), do: value * 1.0
  defp parse_price(value) when is_float(value), do: value

  defp parse_price(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, _} when number >= 0 -> number
      _ -> nil
    end
  end

  defp parse_price(_value), do: nil

  defp variant_floor(variants) do
    variants |> Enum.map(& &1["price"]) |> Enum.min()
  end

  defp variants_of(nil), do: []

  defp variants_of(%{metadata: metadata}) when is_map(metadata) do
    Map.get(metadata, "variants") || Map.get(metadata, :variants) || []
  end

  defp variants_of(_), do: []

  defp extra_images(nil), do: []

  defp extra_images(%{metadata: metadata}) when is_map(metadata) do
    Map.get(metadata, "images") || Map.get(metadata, :images) || []
  end

  defp extra_images(_), do: []

  defp category_of(%{metadata: metadata}) when is_map(metadata) do
    Map.get(metadata, "category") || Map.get(metadata, :category) || ""
  end

  defp category_of(_), do: ""

  defp variant_summary(item) do
    case variants_of(item) do
      [] ->
        if item.price, do: "KES #{format_kes(item.price)}", else: "No price"

      variants ->
        floor = variants |> Enum.map(& &1["price"]) |> Enum.reject(&is_nil/1) |> Enum.min()
        count = length(variants)
        label = if count == 1, do: "variant", else: "variants"
        "KES #{format_kes(floor)} · #{count} #{label}"
    end
  end

  defp format_kes(nil), do: ""
  defp format_kes(price) when is_integer(price), do: Integer.to_string(price)

  defp format_kes(price) when is_float(price) do
    if price == trunc(price) * 1.0 do
      Integer.to_string(trunc(price))
    else
      :erlang.float_to_binary(price, decimals: 2)
    end
  end

  defp format_kes(price) when is_binary(price), do: price

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value) when is_binary(value), do: String.trim(value)
  defp blank_to_nil(value), do: value

  defp ensure_catalog(workspace) do
    case Catalogs.get_catalog(workspace.id) do
      %Catalog{} = catalog ->
        catalog

      nil ->
        {:ok, _catalog} =
          Catalogs.upsert_catalog(workspace.id, %{
            "name" => "Products",
            "entity_label" => "product",
            "context_notes" =>
              "Quote only the KES prices stored on each variant. Never invent a price."
          })

        Catalogs.get_catalog(workspace.id)
    end
  end

  defp clear_item_uploads(socket) do
    Enum.reduce([:cover, :extras], socket, &clear_upload/2)
  end

  defp clear_upload(name, socket) do
    entries = socket.assigns.uploads[name].entries

    Enum.reduce(entries, socket, fn entry, socket ->
      try do
        cancel_upload(socket, name, entry.ref)
      catch
        :exit, _ ->
          conf = socket.assigns.uploads[name]
          Phoenix.LiveView.Upload.drop_upload_entries(socket, conf, [entry.ref])
      end
    end)
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
      categories: [],
      fields: [],
      items: []
    }
  end

  defp add_shop_category(socket, name) do
    catalog = socket.assigns.catalog
    taken = Catalogs.shop_categories(catalog)

    case Catalogs.normalize_category_name(name) do
      nil ->
        {:noreply, put_flash(socket, :error, "Enter a category name.")}

      name ->
        if Enum.any?(taken, &(String.downcase(&1) == String.downcase(name))) do
          {:noreply, assign(socket, :category_query, "")}
        else
          case Catalogs.add_category(catalog, name) do
            {:ok, _catalog} ->
              {:noreply,
               socket
               |> assign(:category_query, "")
               |> reload_products_state(clear_selected_item: false)}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Could not add that category.")}
          end
        end
    end
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
