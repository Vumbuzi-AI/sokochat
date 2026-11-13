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
     |> assign(:workspaces, Workspaces.list_workspaces(socket.assigns.current_user.id))
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
     |> assign(:confirming, nil)
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
     |> assign(:shared_line, nil)
     |> assign(:shop_code, "")
     |> assign(:wa_me_url, nil)
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
     )
     |> allow_variant_uploads(), layout: false}
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
  defp step_title(:cta), do: "Next steps"
  defp step_title(:meta), do: "WhatsApp"
  defp step_title(_), do: "Business"

  defp step_subtitle(:business, _assigns), do: "Shop profile"

  defp step_subtitle(:products, %{catalog: %{id: id, items: items}}) when not is_nil(id) do
    case length(items || []) do
      1 -> "1 product"
      count -> "#{count} products"
    end
  end

  defp step_subtitle(:cta, %{cta_rules: rules}) when rules != [], do: "#{length(rules)} rules"
  defp step_subtitle(_step, _assigns), do: nil

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
     |> assign(:active_modal, nil)
     |> put_flash(:info, "#{field.label} removed.")
     |> reload_products_state(clear_selected_item: false)}
  end

  def handle_event("validate_item", %{"item" => item_params}, socket) do
    changeset =
      socket.assigns.selected_item
      |> current_item(socket.assigns.catalog.id)
      |> Catalogs.change_item(item_params)
      |> Map.put(:action, :validate)

    drafts = drafts_from(item_params["variants"])
    socket = keep_latest_variant_uploads(socket)

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
    slots = drafts_from(item_params["variants"])
    existing = socket.assigns.selected_item

    cond do
      not Enum.any?(slots, &complete_variant?/1) ->
        {:noreply,
         put_flash(socket, :error, "Add at least one variant with a name and a KES price.")}

      is_nil(Catalogs.normalize_category_name(item_params["category"])) ->
        {:noreply, put_flash(socket, :error, "Pick a category.")}

      true ->
        case store_product_images(socket, socket.assigns.catalog.id, existing) do
          {:ok, socket, cover, extras} ->
            case attach_variant_images(socket, socket.assigns.catalog.id, slots) do
              {:error, socket, message} ->
                {:noreply, put_flash(socket, :error, message)}

              {:ok, socket, variants} ->
                persist_item(socket, item_params, existing, variants, cover, extras)
            end

          {:error, socket, message} ->
            {:noreply, put_flash(socket, :error, message)}
        end
    end
  end

  defp persist_item(socket, item_params, existing, variants, cover, extras) do
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
        {:noreply, assign_form(socket, :item_form, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("add_variant", _params, socket) do
    drafts = socket.assigns.variant_drafts

    drafts =
      if length(drafts) < @variant_slots do
        drafts ++ [blank_variant(drafts)]
      else
        drafts
      end

    {:noreply, assign(socket, :variant_drafts, drafts)}
  end

  def handle_event("remove_variant", %{"index" => index}, socket) do
    index = String.to_integer(index)
    {slot, drafts} = List.pop_at(socket.assigns.variant_drafts, index)
    socket = cancel_variant_upload(socket, slot)
    drafts = if drafts == [], do: empty_variant_slots(), else: drafts

    {:noreply, assign(socket, :variant_drafts, drafts)}
  end

  def handle_event("clear_variant_photo", %{"index" => index}, socket) do
    index = String.to_integer(index)
    drafts = socket.assigns.variant_drafts
    slot = Enum.at(drafts, index) || %{}
    socket = cancel_variant_upload(socket, slot)

    slot =
      slot
      |> Map.put("image_url", "")
      |> Map.put("clear_image", "true")

    {:noreply, assign(socket, :variant_drafts, List.replace_at(drafts, index, slot))}
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

  def handle_event("confirm_delete", %{"kind" => kind, "id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:confirming, confirmation(kind, id, socket.assigns))
     |> assign(:active_modal, :confirm_delete)}
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    item = Catalogs.get_item!(socket.assigns.catalog.id, normalize_id(id))
    {:ok, _} = Catalogs.delete_item(item)

    {:noreply,
     socket
     |> assign(:active_modal, nil)
     |> put_flash(:info, "#{item.title} deleted.")
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
     |> assign(:active_modal, nil)
     |> put_flash(:info, "Rule deleted.")
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

  def handle_event("update_shop_code", %{"shop_code" => shop_code}, socket) do
    {:noreply, assign(socket, :shop_code, shop_code)}
  end

  def handle_event("join_shared_line", _params, socket) do
    shared_line = socket.assigns.shared_line

    case Meta.join_shared_line(socket.assigns.workspace, shared_line, socket.assigns.shop_code) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:shop_code, workspace.shop_code)
         |> assign(:wa_me_url, Meta.shop_wa_me_url(shared_line, workspace))
         |> assign(:meta_configured, shared_line.status == "active")
         |> put_flash(:info, "This shop now uses the shared WhatsApp line.")}

      {:error, %Changeset{} = changeset} ->
        message =
          changeset
          |> Changeset.traverse_errors(fn {msg, _opts} -> msg end)
          |> Enum.map(fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
          |> Enum.join("; ")

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("leave_shared_line", _params, socket) do
    case Meta.leave_shared_line(socket.assigns.workspace) do
      {:ok, workspace} ->
        connection = socket.assigns.connection

        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:shop_code, workspace.slug)
         |> assign(:wa_me_url, nil)
         |> assign(:meta_configured, connection && connection.status == "active")
         |> put_flash(:info, "This shop left the shared WhatsApp line.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not leave the shared line.")}
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

  def handle_info({:ai_turn_failed, workspace_id, reason}, socket) do
    if socket.assigns.workspace && socket.assigns.workspace.id == workspace_id,
      do: {:noreply, put_flash(socket, :error, reason)},
      else: {:noreply, socket}
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
      workspaces={@workspaces}
      current_user={@current_user}
      tab={@active_step}
      title={@page_title}
      subtitle={step_subtitle(@active_step, assigns)}
      flash={@flash}
      inbox_counts={@inbox_counts}
    >
      <:actions :if={@active_step == :business}>
        <.button form="business-form" size="sm" disabled={business_unchanged?(@business_form)}>
          Save changes
        </.button>
      </:actions>
      <:actions :if={
        @active_step == :products and not is_nil(@catalog.id) and (@catalog.items || []) != []
      }>
        <.button type="button" size="sm" phx-click="new_item">
          <.icon name="plus" /> Add product
        </.button>
      </:actions>
      <:actions :if={@active_step == :cta and @cta_rules != []}>
        <.recommend_button recommending={@recommending} />
        <.button type="button" size="sm" phx-click="open_add_rule">
          <.icon name="plus" /> Add rule
        </.button>
      </:actions>

      <.business_step :if={@active_step == :business} {assigns} />
      <.products_step :if={@active_step == :products} {assigns} />
      <.cta_step :if={@active_step == :cta} {assigns} />
      <.meta_step :if={@active_step == :meta} {assigns} />

      <.catalog_model_modal :if={@active_modal == :model} {assigns} />
      <.field_modal :if={@active_modal == :field} {assigns} />
      <.item_modal :if={@active_modal == :item} {assigns} />
      <.confirm_delete_modal :if={@active_modal == :confirm_delete} confirming={@confirming} />
      <.cta_rule_modal :if={@active_modal == :cta_rule} {assigns} />
    </.shell>
    """
  end

  # --- business ------------------------------------------------------------

  defp business_step(assigns) do
    ~H"""
    <.simple_form
      id="business-form"
      for={@business_form}
      phx-change="validate_business"
      phx-submit="save_business"
      class="max-w-[880px] !gap-0"
    >
      <.section
        title="Business profile"
        text="Sokochat uses this to describe your shop when buyers ask."
      >
        <.input field={@business_form[:company_name]} label="Business name" placeholder="Soko Shoes" />
        <div class="soko-field-row">
          <.input field={@business_form[:industry]} label="Industry" placeholder="Footwear" />
          <.input
            field={@business_form[:phone_number]}
            type="tel"
            label="Phone"
            placeholder="+254 712 345 678"
          />
        </div>
        <.input field={@business_form[:location]} label="Location" placeholder="Moi Avenue, Nairobi" />
      </.section>

      <.section
        title="AI content"
        text="Filled from your website when the shop is created. Sokochat uses this in replies. Change anything that is off."
      >
        <.input
          field={@business_form[:ai_instructions]}
          type="textarea"
          label="What Sokochat should know"
          rows="6"
          placeholder="We sell sneakers in Nairobi. Sizes are EU. Prices are in KES. Same-day delivery inside the city."
        />
      </.section>

      <.section
        title="About"
        text="A few lines buyers might ask about, like delivery or opening hours."
      >
        <.input
          field={@business_form[:about]}
          type="textarea"
          label="Shop notes"
          rows="4"
          placeholder="We deliver in Nairobi the same day. Open Monday to Saturday, 9am to 7pm."
        />
      </.section>

      <.section title="WhatsApp line" text={whatsapp_line_text(@workspace)}>
        <div
          :if={@workspace.shared_line_id && @wa_me_url}
          class="flex items-center gap-3 rounded-[12px] border border-soko-line bg-soko-white px-4 py-3"
        >
          <.icon name="whatsapp-logo" class="h-4 w-4 flex-none text-soko-ink-2" />
          <span class="min-w-0 flex-1 truncate text-sm">{display_link(@wa_me_url)}</span>
          <.badge>Connected</.badge>
          <.button
            id="copy-wa-me"
            type="button"
            tone="secondary"
            size="sm"
            phx-hook="ClipboardCopy"
            data-copy={@wa_me_url}
          >
            <.icon name="copy" /> Copy link
          </.button>
        </div>
        <div
          :if={!(@workspace.shared_line_id && @wa_me_url)}
          class="flex items-center gap-3 rounded-[12px] border border-soko-line bg-soko-white px-4 py-3"
        >
          <.icon name="whatsapp-logo" class="h-4 w-4 flex-none text-soko-ink-3" />
          <span class="min-w-0 flex-1 text-sm text-soko-ink-2">Not connected yet</span>
          <.button navigate={~p"/workspaces/#{@workspace.id}/connection"} tone="secondary" size="sm">
            Connect
          </.button>
        </div>
      </.section>
    </.simple_form>
    """
  end

  defp whatsapp_line_text(workspace) do
    "Buyers reach #{workspace.company_name || workspace.name} through the shared Sokochat number."
  end

  defp display_link(url), do: String.replace(url, ~r{^https?://}, "")

  # --- products -----------------------------------------------------------

  defp products_step(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <div :if={!@catalog.id} class="grid min-h-[60vh] place-items-center">
        <.empty
          icon="package"
          title="Set up your catalogue"
          text="Tell Sokochat what you sell, then add products one by one."
        >
          <:actions>
            <.button type="button" size="sm" phx-click="open_model">Set up catalogue</.button>
          </:actions>
        </.empty>
      </div>

      <div :if={@catalog.id} class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2" role="tablist" aria-label="Catalogue">
          <button
            :for={
              {tab, label} <- [
                {"manual", "Products"},
                {"categories", "Categories"},
                {"fields", "Fields"}
              ]
            }
            type="button"
            role="tab"
            class="soko-chip"
            data-active={to_string(products_tab(@active_tab) == tab)}
            aria-selected={to_string(products_tab(@active_tab) == tab)}
            phx-click="switch_tab"
            phx-value-tab={tab}
          >
            {label}
          </button>
        </div>
        <.source_banner source="manual" active={@workspace.data_source} />
      </div>

      <div :if={@catalog.id && products_tab(@active_tab) == "manual"}>
        <.products_table items={@catalog.items || []} />
      </div>

      <.categories_panel
        :if={@catalog.id && @active_tab == "categories"}
        categories={Catalogs.shop_categories(@catalog)}
        query={@category_query}
      />

      <.fields_panel :if={@catalog.id && @active_tab == "fields"} fields={@custom_fields} />

      <div :if={@active_tab == "api"} class="flex max-w-[640px] flex-col gap-4">
        <.source_banner source="api" active={@workspace.data_source} />
        <.banner :if={@endpoint.last_fetched_at}>
          Last fetched {last_fetched_label(@endpoint.last_fetched_at)}
        </.banner>
        <.banner :if={@test_error} tone="danger">{@test_error}</.banner>

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
            label="Refresh"
            options={[
              {"On demand", "on_demand"},
              {"Every 60 seconds", "poll_60s"},
              {"Every 5 minutes", "poll_300s"}
            ]}
          />
          <:actions>
            <.button type="submit" name="endpoint[action]" value="test" tone="secondary">
              Test connection
            </.button>
            <.button name="endpoint[action]" value="save">Save endpoint</.button>
          </:actions>
        </.simple_form>
      </div>

      <div :if={@active_tab == "preview"} class="flex flex-col gap-3">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <p class="text-sm text-soko-ink-2">
            {preview_caption(@preview_label, @workspace.data_source)}
          </p>
          <.button
            type="button"
            tone="secondary"
            size="sm"
            phx-click="regenerate_ai_context"
            phx-disable-with="Regenerating"
          >
            <.icon name="arrow-clockwise" /> Regenerate AI context
          </.button>
        </div>
        <pre
          :if={@preview_json}
          class="overflow-x-auto rounded-soko-14 border border-soko-line bg-soko-white px-5 py-4 font-mono text-xs leading-5"
        ><%= @preview_json %></pre>
        <p :if={!@preview_json} class="text-sm text-soko-ink-2">
          Nothing to preview yet. Add products or connect a feed first.
        </p>
      </div>
    </div>
    """
  end

  defp preview_caption(label, source) do
    from = if source == "api", do: "your live feed", else: "your catalogue"
    "#{label || "The shop context"} Sokochat reads from #{from}."
  end

  defp products_tab(tab) when tab in ["categories", "fields", "api", "preview"], do: tab
  defp products_tab(_tab), do: "manual"

  attr :items, :list, required: true

  defp products_table(assigns) do
    ~H"""
    <div :if={@items == []} class="grid min-h-[50vh] place-items-center">
      <.empty
        icon="package"
        title="No products yet"
        text="Add your first product so Sokochat can answer buyers with it."
      >
        <:actions>
          <.button type="button" phx-click="new_item"><.icon name="plus" /> Add product</.button>
        </:actions>
      </.empty>
    </div>

    <.table :if={@items != []} id="products" rows={@items} row_id={&"item-#{&1.id}"}>
      <:col :let={item} label="Product">
        <span class="flex min-w-0 items-center gap-3">
          <img :if={item.image_url} src={item.image_url} alt="" class="soko-thumb" />
          <span :if={!item.image_url} class="soko-thumb grid place-items-center text-soko-ink-3">
            <.icon name="image" class="h-4 w-4" />
          </span>
          <span class="truncate font-medium">{item.title}</span>
        </span>
      </:col>
      <:col :let={item} label="Category">
        <span class="text-soko-ink-2">{category_of(item)}</span>
      </:col>
      <:col :let={item} label="Variants">
        <span class="text-soko-ink-2">{variant_count_label(item)}</span>
      </:col>
      <:col :let={item} label="From" align="right">{price_from_label(item)}</:col>
      <:col :let={item} label="Status">
        <.badge tone={status_tone(item.status)}>{status_label(item.status)}</.badge>
      </:col>
      <:action :let={item}>
        <.icon_button
          icon="pencil-simple"
          phx-click="edit_item"
          phx-value-id={item.id}
          aria-label={"Edit #{item.title}"}
        />
        <.icon_button
          icon="trash"
          phx-click="confirm_delete"
          phx-value-kind="item"
          phx-value-id={item.id}
          aria-label={"Delete #{item.title}"}
        />
      </:action>
    </.table>
    """
  end

  defp variant_count_label(item) do
    variants = variants_of(item)

    base =
      case variants do
        [] -> "One price"
        [_] -> "1 variant"
        list -> "#{length(list)} variants"
      end

    photos = Enum.count(variants, &variant_photo?/1)
    photo_label = if photos == 1, do: "1 photo", else: "#{photos} photos"
    if photos > 0, do: "#{base} · #{photo_label}", else: base
  end

  defp variant_photo?(%{"image_url" => url}) when is_binary(url) and url != "", do: true
  defp variant_photo?(_variant), do: false

  defp price_from_label(item) do
    prices =
      item
      |> variants_of()
      |> Enum.map(& &1["price"])
      |> Enum.reject(&is_nil/1)

    case {prices, item.price} do
      {[], nil} -> "No price"
      {[], price} -> kes(price)
      {prices, _} -> kes(Enum.min(prices))
    end
  end

  defp kes(price) when is_number(price) do
    whole = price |> round() |> Integer.to_string()

    grouped =
      whole
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(",", &Enum.join/1)
      |> String.reverse()

    "KES #{grouped}"
  end

  defp kes(price), do: "KES #{format_kes(price)}"

  defp status_tone(status) when status in [nil, "active"], do: "success"
  defp status_tone(_status), do: "neutral"

  defp status_label(nil), do: "Active"
  defp status_label(status), do: String.capitalize(status)

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
    <div class="max-w-[640px] rounded-soko-14 border border-soko-line bg-soko-white p-4">
      <h2 class="soko-section-title">Categories</h2>
      <p class="soko-section-text">Choose what you sell. Each product picks one.</p>

      <form
        id="shop-categories"
        phx-change="filter_categories"
        phx-submit="add_category"
        class="mt-4 flex items-end gap-2"
      >
        <.input
          type="search"
          name="category[query]"
          id="category-query"
          value={@query}
          label="Category"
          autocomplete="off"
          placeholder="Search or type a category"
          class="min-w-0 flex-1"
        />
        <.button type="submit" tone="secondary"><.icon name="plus" /> Add</.button>
      </form>

      <div
        :if={String.trim(@query) != ""}
        class="mt-2 rounded-[12px] border border-soko-line bg-soko-white p-1"
      >
        <button
          :for={name <- @suggestions}
          type="button"
          phx-click="add_category"
          phx-value-name={name}
          class="flex h-9 w-full items-center justify-between rounded-lg px-2 text-left text-sm hover:bg-soko-hover"
        >
          {name} <span class="soko-mono text-soko-ink-3">Suggested</span>
        </button>
        <button
          type="submit"
          form="shop-categories"
          class="flex h-9 w-full items-center gap-2 rounded-lg px-2 text-left text-sm font-medium text-soko-forest hover:bg-soko-hover"
        >
          <.icon name="plus" class="h-4 w-4" /> Add “{String.trim(@query)}” as a new category
        </button>
      </div>

      <p class="soko-mono mt-4 text-soko-ink-3">Your categories · {length(@categories)}</p>
      <div class="mt-2 flex flex-wrap gap-2">
        <span
          :for={name <- @categories}
          class="inline-flex h-7 items-center gap-1.5 rounded-full bg-soko-stage pl-3 pr-2 text-sm font-medium"
        >
          {name}
          <button
            type="button"
            phx-click="remove_category"
            phx-value-name={name}
            aria-label={"Remove #{name}"}
            class="grid h-4 w-4 place-items-center text-soko-ink-2 hover:text-soko-danger"
          >
            <.icon name="x" class="h-3 w-3" />
          </button>
        </span>
        <span :if={@categories == []} class="text-sm text-soko-ink-2">
          No categories yet. Search the list or type your own.
        </span>
      </div>
    </div>
    """
  end

  attr :fields, :list, required: true

  defp fields_panel(assigns) do
    ~H"""
    <div class="max-w-[640px] rounded-soko-14 border border-soko-line bg-soko-white p-4">
      <div class="flex items-start justify-between gap-3">
        <div>
          <h2 class="soko-section-title">Fields</h2>
          <p class="soko-section-text">
            Every product has a name, category, description, price, photo and status. Add fields for anything else buyers ask about.
          </p>
        </div>
        <.button type="button" tone="secondary" size="sm" phx-click="new_field">
          <.icon name="plus" /> Add field
        </.button>
      </div>

      <div class="mt-4 overflow-hidden rounded-[12px] border border-soko-line">
        <div
          :for={field <- @fields}
          class="flex items-center gap-3 border-b border-soko-divider px-4 py-3 last:border-b-0"
        >
          <div class="min-w-0 flex-1">
            <p class="text-sm font-medium">{field.label}</p>
            <p :if={field.help_text} class="truncate text-xs text-soko-ink-2">{field.help_text}</p>
          </div>
          <.badge tone="neutral">{humanize_field_type(field.field_type)}</.badge>
          <.badge :if={field.required} tone="waiting">Required</.badge>
          <.icon_button
            icon="pencil-simple"
            phx-click="edit_field"
            phx-value-id={field.id}
            aria-label={"Edit #{field.label}"}
          />
          <.icon_button
            icon="trash"
            phx-click="confirm_delete"
            phx-value-kind="field"
            phx-value-id={field.id}
            aria-label={"Remove #{field.label}"}
          />
        </div>
        <p :if={@fields == []} class="px-4 py-6 text-center text-sm text-soko-ink-2">
          No extra fields yet.
        </p>
      </div>
    </div>
    """
  end

  defp humanize_field_type("image_url"), do: "Image link"
  defp humanize_field_type("url"), do: "Link"
  defp humanize_field_type("boolean"), do: "Yes or no"
  defp humanize_field_type("textarea"), do: "Long text"
  defp humanize_field_type(type) when is_binary(type), do: String.capitalize(type)
  defp humanize_field_type(_type), do: "Text"

  # --- cta rules ------------------------------------------------------------

  defp cta_step(assigns) do
    ~H"""
    <div class="flex max-w-[880px] flex-col gap-4">
      <p class="text-sm text-soko-ink-2">
        Tell Sokochat which next step to offer when a buyer asks, like a call, a map pin or a link.
      </p>

      <.cta_suggestions :if={@cta_suggestions != []} suggestions={@cta_suggestions} />

      <div
        :if={@cta_rules == [] and @cta_suggestions == []}
        class="grid min-h-[50vh] place-items-center"
      >
        <.empty
          icon="cursor-click"
          title="No rules yet"
          text="Add a rule for each thing buyers ask for, or let Sokochat suggest rules from your products."
        >
          <:actions>
            <.recommend_button recommending={@recommending} tone="primary" />
            <.button type="button" tone="secondary" size="sm" phx-click="open_add_rule">
              Add manually
            </.button>
          </:actions>
        </.empty>
      </div>

      <.table :if={@cta_rules != []} id="cta-rules" rows={@cta_rules} row_id={&"cta-rule-#{&1.id}"}>
        <:col :let={rule} label="#">
          <span class="font-mono text-xs text-soko-ink-3">{rule.priority}</span>
        </:col>
        <:col :let={rule} label="When the buyer">
          <span class="font-medium">{rule.trigger_description}</span>
        </:col>
        <:col :let={rule} label="Action">
          <span class="inline-flex items-center gap-2 text-soko-ink-2">
            <.icon name={cta_icon(rule.cta_type)} class="h-4 w-4" />
            {humanize_cta_type(rule.cta_type)}
          </span>
        </:col>
        <:col :let={rule} label="Sends">
          <span class="block max-w-[220px] truncate font-mono text-xs text-soko-ink-2">
            {payload_summary(rule)}
          </span>
        </:col>
        <:action :let={rule}>
          <.icon_button
            icon="pencil-simple"
            phx-click="edit_rule"
            phx-value-id={rule.id}
            aria-label="Edit rule"
          />
          <.icon_button
            icon="trash"
            phx-click="confirm_delete"
            phx-value-kind="rule"
            phx-value-id={rule.id}
            aria-label="Delete rule"
          />
        </:action>
      </.table>
    </div>
    """
  end

  attr :recommending, :boolean, required: true
  attr :tone, :string, default: "secondary"

  defp recommend_button(assigns) do
    ~H"""
    <.button type="button" tone={@tone} size="sm" phx-click="recommend_ctas" disabled={@recommending}>
      <.icon
        name={if @recommending, do: "arrow-clockwise", else: "sparkle"}
        class={@recommending && "animate-spin"}
      />
      {if @recommending, do: "Suggesting", else: "Suggest rules"}
    </.button>
    """
  end

  attr :suggestions, :list, required: true

  defp cta_suggestions(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <p class="soko-mono text-soko-ink-3">Suggested · review and add the ones you want</p>
      <div class="overflow-hidden rounded-soko-14 border border-soko-line bg-soko-white">
        <div
          :for={{suggestion, index} <- Enum.with_index(@suggestions)}
          class="flex items-center gap-3 border-b border-soko-divider px-4 py-3 last:border-b-0"
        >
          <span class="grid h-9 w-9 flex-none place-items-center rounded-[10px] bg-soko-stage text-soko-forest">
            <.icon name={cta_icon(suggestion["cta_type"])} class="h-4 w-4" />
          </span>
          <div class="min-w-0 flex-1">
            <p class="text-sm font-medium">{suggestion["trigger_description"]}</p>
            <p class="truncate text-xs text-soko-ink-2">
              {humanize_cta_type(suggestion["cta_type"])} · {suggestion_summary(suggestion)}
            </p>
          </div>
          <.button
            type="button"
            tone="secondary"
            size="sm"
            phx-click="add_suggestion"
            phx-value-index={index}
          >
            <.icon name="plus" /> Add
          </.button>
          <.icon_button
            icon="x"
            phx-click="dismiss_suggestion"
            phx-value-index={index}
            aria-label="Dismiss suggestion"
          />
        </div>
      </div>
    </div>
    """
  end

  # --- meta -------------------------------------------------------------------

  defp meta_step(assigns) do
    ~H"""
    <div class="flex max-w-[880px] flex-col">
      <.section
        title="Meta Verification Pipeline"
        text="Connect this shop to WhatsApp with its own number, or join the shared line so several shops use one number."
      >
        <.banner :if={@meta_configured}>
          <p class="font-medium">Pre-Live Stage Validated</p>
          <p class="text-soko-ink-2">
            Your catalogue and replies are ready. Add your Meta details to go live on your own number.
          </p>
        </.banner>
        <.link navigate={~p"/shared-line"} class="soko-link text-sm">Manage the shared line</.link>
      </.section>

      <.section
        :if={@shared_line && @shared_line.id}
        title="Use the shared line"
        text="Buyers open a prefilled wa.me link and land in this shop."
      >
        <div :if={is_nil(@workspace.shared_line_id)} class="flex items-end gap-2">
          <form phx-change="update_shop_code" class="min-w-0 flex-1">
            <.input type="text" name="shop_code" id="shop-code" value={@shop_code} label="Shop code" />
          </form>
          <.button type="button" phx-click="join_shared_line">Join shared line</.button>
        </div>

        <div :if={@workspace.shared_line_id} class="flex flex-col gap-3">
          <p class="text-sm">
            Joined as <span class="font-mono text-xs">[shop:{@workspace.shop_code}]</span>
          </p>
          <.copy_field :if={@wa_me_url} id="shop-wa-me" label="Buyer link" value={@wa_me_url} />
          <div>
            <.button type="button" tone="secondary" size="sm" phx-click="leave_shared_line">
              Leave shared line
            </.button>
          </div>
        </div>
      </.section>

      <.section
        :if={is_nil(@workspace.shared_line_id)}
        title="Your own number"
        text="The access token is encrypted. Saving new details sets the connection back to pending until the webhook is verified again."
      >
        <.banner
          :for={alert <- meta_alerts(@connection, @data_ingestion_configured, @cta_rules_configured)}
          tone={banner_tone(alert.tone)}
        >
          <p class="font-medium">{alert.title}</p>
          <p>{alert.body}</p>
        </.banner>

        <.banner :if={@connection.last_error} tone="danger">{@connection.last_error}</.banner>

        <.simple_form for={@meta_form} phx-change="validate" phx-submit="save">
          <div class="soko-field-row">
            <.input field={@meta_form[:phone_number_id]} label="Phone Number ID" required />
            <.input field={@meta_form[:waba_id]} label="WhatsApp Business Account ID" required />
          </div>
          <.input
            field={@meta_form[:access_token]}
            type="password"
            label="Permanent access token"
            required
            autocomplete="off"
          />
          <:actions>
            <.button size="sm">Save details</.button>
          </:actions>
        </.simple_form>
      </.section>

      <.section
        :if={is_nil(@workspace.shared_line_id) and persisted?(@connection)}
        title="Webhook"
        text="In your Meta app, open WhatsApp, Configuration, Webhooks. Paste these values and subscribe to messages."
      >
        <.copy_field
          id="webhook-url"
          label="Callback URL"
          value={webhook_url(@socket, @workspace.slug)}
        />
        <.copy_field id="verify-token" label="Verify token" value={@connection.verify_token} />
        <div class="flex flex-col gap-2 rounded-[12px] border border-soko-line bg-soko-white p-4">
          <.checklist_item done={true} label="Details saved" />
          <.checklist_item
            done={not is_nil(@connection.webhook_verified_at)}
            label={"Webhook verified, #{verified_label(@connection.webhook_verified_at)}"}
          />
          <.checklist_item
            done={@connection.status == "active"}
            label="Connection active and ready for messages"
          />
        </div>
      </.section>
    </div>
    """
  end

  defp banner_tone(:warning), do: "waiting"
  defp banner_tone(_tone), do: "info"

  # --- shared small components --------------------------------------------

  attr :source, :string, required: true
  attr :active, :string, required: true

  defp source_banner(assigns) do
    assigns = assign(assigns, :is_active, assigns.source == assigns.active)

    ~H"""
    <span :if={@is_active} class="inline-flex items-center gap-2 text-xs text-soko-ink-2">
      <.badge>AI source</.badge>
      Sokochat answers from this
    </span>
    <span :if={not @is_active} class="inline-flex items-center gap-2 text-xs text-soko-ink-2">
      <.badge tone="neutral">Not in use</.badge>
      <.button
        type="button"
        tone="secondary"
        size="sm"
        phx-click="set_data_source"
        phx-value-source={@source}
      >
        Use as AI source
      </.button>
    </span>
    """
  end

  # --- modals -------------------------------------------------------------

  defp catalog_model_modal(assigns) do
    ~H"""
    <.modal id="catalog-model" title="Catalogue" text="Tell Sokochat what your catalogue holds.">
      <.simple_form for={@catalog_form} phx-change="validate_model" phx-submit="save_model">
        <.input field={@catalog_form[:name]} label="Catalogue name" required />
        <.input
          field={@catalog_form[:entity_label]}
          label="You sell"
          placeholder="product, service, menu item"
          required
        />
        <.input
          field={@catalog_form[:context_notes]}
          type="textarea"
          label="Notes for Sokochat"
          placeholder="How to read the catalogue, like sizes are EU and prices are per pair."
        />
        <:actions>
          <.button type="button" tone="secondary" phx-click="close_modal">Cancel</.button>
          <.button>Save catalogue</.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  defp field_modal(assigns) do
    ~H"""
    <.modal
      id="field-modal"
      title={if @selected_field, do: "Edit field", else: "Add field"}
      text="Saved on each product and included in replies."
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
          label="Type"
          options={[
            {"Text", "text"},
            {"Long text", "textarea"},
            {"Number", "number"},
            {"Link", "url"},
            {"Image link", "image_url"},
            {"Yes or no", "boolean"},
            {"JSON", "json"}
          ]}
        />
        <.input field={@field_form[:required]} type="checkbox" label="Required" />
        <.input
          field={@field_form[:help_text]}
          type="textarea"
          label="Help text"
          rows="2"
          placeholder="Shown under the field when you add a product"
        />
        <:actions>
          <.button type="button" tone="secondary" phx-click="close_modal">Cancel</.button>
          <.button>{if @selected_field, do: "Save field", else: "Add field"}</.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  attr :confirming, :map, required: true

  defp confirm_delete_modal(assigns) do
    ~H"""
    <.modal
      id="confirm-delete"
      tone="danger"
      size="sm"
      title={@confirming.title}
      text={@confirming.text}
    >
      <:actions>
        <.button type="button" tone="secondary" phx-click="close_modal">Cancel</.button>
        <.button
          type="button"
          tone="danger"
          phx-click={@confirming.event}
          phx-value-id={@confirming.id}
        >
          <.icon name="trash" /> {@confirming.label}
        </.button>
      </:actions>
    </.modal>
    """
  end

  defp confirmation("item", id, assigns) do
    item = Catalogs.get_item!(assigns.catalog.id, normalize_id(id))

    %{
      event: "delete_item",
      id: item.id,
      title: "Delete #{item.title}?",
      text:
        "Sokochat stops offering it to buyers. Its photos and prices are removed. You can't undo this.",
      label: "Delete product"
    }
  end

  defp confirmation("field", id, assigns) do
    field = Catalogs.get_field!(assigns.catalog.id, normalize_id(id))

    %{
      event: "delete_field",
      id: field.id,
      title: "Remove #{field.label}?",
      text: "It comes off every product, along with what you saved in it. You can't undo this.",
      label: "Remove field"
    }
  end

  defp confirmation("rule", id, assigns) do
    rule = CTARules.get_cta_rule!(id, assigns.workspace.id)

    %{
      event: "delete_rule",
      id: rule.id,
      title: "Delete this rule?",
      text: "Sokochat stops offering this next step when buyers ask: #{rule.trigger_description}",
      label: "Delete rule"
    }
  end

  defp item_modal(assigns) do
    assigns = assign(assigns, :can_save, product_can_save?(assigns))

    ~H"""
    <.modal
      id="item-modal"
      size="lg"
      title={if @selected_item, do: "Edit product", else: "New product"}
      text="Name, one cover photo and a price for each variant in KES. A variant can have its own photo."
    >
      <.form
        for={@item_form}
        phx-change="validate_item"
        phx-submit="save_item"
        phx-debounce="200"
        multipart
        class="soko-form"
      >
        <input type="hidden" name="item[id]" value={(@selected_item && @selected_item.id) || ""} />
        <input type="hidden" name="item[status]" value="active" />
        <.input field={@item_form[:title]} label="Name" placeholder="Nike Shox" required />
        <.select_menu
          id="item-category"
          name="item[category]"
          label="Category"
          prompt="Select a category"
          options={category_options(@catalog, @category_draft)}
          value={@category_draft}
          hint={Catalogs.shop_categories(@catalog) == [] && "Add categories on Products first."}
        />
        <.input field={@item_form[:description]} type="textarea" label="Description" rows="3" />

        <div class="flex flex-col gap-3">
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="soko-label">Variants</p>
              <p class="soko-hint">
                At least one, like a size or colour. Add a photo when that one looks different. Prices in KES.
              </p>
            </div>
            <.button
              type="button"
              tone="secondary"
              size="sm"
              phx-click="add_variant"
              disabled={length(@variant_drafts) >= 4}
            >
              <.icon name="plus" /> Add variant
            </.button>
          </div>
          <.variant_row
            :for={{slot, index} <- Enum.with_index(@variant_drafts)}
            slot={slot}
            index={index}
            uploads={@uploads}
            only={length(@variant_drafts) == 1}
          />
        </div>

        <div :if={@details_open} class="form-reveal flex flex-col gap-4">
          <div class="soko-field-row">
            <div class="flex flex-col gap-2">
              <p class="soko-label">Cover image</p>
              <img
                :if={@selected_item && @selected_item.image_url}
                src={@selected_item.image_url}
                alt=""
                class="soko-thumb h-16 w-16"
              />
              <div class="soko-box">
                <.live_file_input upload={@uploads.cover} class="soko-control" />
              </div>
              <p class="soko-hint">JPG, PNG or WEBP.</p>
            </div>
            <div class="flex flex-col gap-2">
              <p class="soko-label">More photos</p>
              <div :if={extra_images(@selected_item) != []} class="flex flex-wrap gap-2">
                <img
                  :for={url <- extra_images(@selected_item)}
                  src={url}
                  alt=""
                  class="soko-thumb h-16 w-16"
                />
              </div>
              <div class="soko-box">
                <.live_file_input upload={@uploads.extras} class="soko-control" />
              </div>
              <p class="soko-hint">Optional. Up to four.</p>
            </div>
          </div>

          <div :if={@custom_fields != []} class="flex flex-col gap-3">
            <div>
              <p class="soko-label">More details</p>
              <p class="soko-hint">Saved with the product and used in replies.</p>
            </div>
            <div class="soko-field-row">
              <.custom_field :for={field <- @custom_fields} field={field} values={@item_values} />
            </div>
          </div>
        </div>

        <div class="soko-form-actions">
          <.button type="button" tone="secondary" phx-click="close_modal">Cancel</.button>
          <.button disabled={not @can_save}>
            {if @selected_item, do: "Save product", else: "Add product"}
          </.button>
        </div>
      </.form>
    </.modal>
    """
  end

  defp cta_rule_modal(assigns) do
    ~H"""
    <.modal
      id="cta-rule"
      size="lg"
      title={if @editing_rule, do: "Edit rule", else: "Add rule"}
      text="One buyer request per rule. Sokochat uses the first rule that matches."
    >
      <.simple_form for={@cta_form} phx-change="validate_rule" phx-submit="save_rule">
        <.input
          field={@cta_form[:trigger_description]}
          type="textarea"
          label="When the buyer"
          rows="2"
          placeholder="asks about price or wants to buy"
          required
        />
        <div class="soko-field-row">
          <.input
            field={@cta_form[:cta_type]}
            type="select"
            label="Action"
            options={RuleForm.cta_type_options()}
          />
          <.input field={@cta_form[:priority]} type="number" label="Order" min="1" required />
        </div>

        <%= case @cta_form[:cta_type].value do %>
          <% "website" -> %>
            <.input
              field={@cta_form[:url]}
              label="Website link"
              placeholder="https://sokoshoes.co.ke/checkout"
            />
          <% "phone" -> %>
            <.input field={@cta_form[:phone_number]} label="Phone" placeholder="+254 712 345 678" />
          <% "whatsapp" -> %>
            <.input
              field={@cta_form[:whatsapp_number]}
              label="WhatsApp number"
              placeholder="+254 712 345 678"
            />
          <% "reply_buttons" -> %>
            <div class="flex flex-col gap-3 rounded-[12px] border border-soko-line bg-soko-white p-4">
              <p class="soko-label">Reply buttons <span class="soko-hint">Up to three.</span></p>
              <.input
                :for={field_name <- RuleForm.button_fields()}
                field={@cta_form[field_name]}
                label={Phoenix.Naming.humanize(Atom.to_string(field_name))}
              />
            </div>
          <% "list_message" -> %>
            <div class="flex flex-col gap-3 rounded-[12px] border border-soko-line bg-soko-white p-4">
              <p class="soko-label">
                List items <span class="soko-hint">Rows need a title and a description.</span>
              </p>
              <div :for={index <- RuleForm.list_item_indexes()} class="soko-field-row">
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
            <div class="soko-field-row">
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
              label="Message"
              placeholder="Share the shop map and ask the buyer when they'd like to visit."
            />
          <% _ -> %>
        <% end %>

        <:actions>
          <.button type="button" tone="secondary" phx-click="close_modal">Cancel</.button>
          <.button>{if @editing_rule, do: "Save rule", else: "Add rule"}</.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  attr :field, :map, required: true
  attr :values, :map, required: true

  defp custom_field(assigns) do
    assigns = assign(assigns, :name, "item[metadata][#{assigns.field.key}]")

    ~H"""
    <%= case @field.field_type do %>
      <% "boolean" -> %>
        <.input
          type="checkbox"
          id={"meta-#{@field.key}"}
          name={@name}
          label={@field.label}
          checked={truthy?(Map.get(@values, @field.key))}
        />
      <% type -> %>
        <.input
          type={custom_input_type(type)}
          id={"meta-#{@field.key}"}
          name={@name}
          label={@field.label}
          hint={@field.help_text}
          value={Map.get(@values, @field.key, "")}
          required={@field.required}
          step={type == "number" && "any"}
        />
    <% end %>
    """
  end

  defp custom_input_type("textarea"), do: "textarea"
  defp custom_input_type("number"), do: "number"
  defp custom_input_type(type) when type in ["url", "image_url"], do: "url"
  defp custom_input_type(_type), do: "text"

  # ========================================================================
  # state loading
  # ========================================================================

  defp load_workspace(socket, workspace) do
    endpoint = Endpoints.get_endpoint(workspace.id) || default_endpoint(workspace.id)
    catalog = ensure_catalog(workspace)
    cta_rules = CTARules.list_cta_rules(workspace.id)
    connection = Meta.get_connection_or_new(workspace.id)
    shared_line = Meta.get_shared_line(workspace.account_id)

    phone_number = Conversations.playground_phone_number(workspace.id)
    conversation = Conversations.get_conversation(workspace.id, phone_number, :playground)
    messages = if conversation, do: Conversations.list_messages(conversation.id), else: []

    meta_configured =
      if workspace.shared_line_id do
        shared_line && shared_line.status == "active"
      else
        connection.status == "active"
      end

    socket
    |> assign(:workspace, workspace)
    |> assign(:endpoint, endpoint)
    |> assign(:catalog, catalog)
    |> assign(:cta_rules, sort_rules(cta_rules))
    |> assign(:connection, connection)
    |> assign(:shared_line, shared_line)
    |> assign(:shop_code, workspace.shop_code || workspace.slug)
    |> assign(:wa_me_url, Meta.shop_wa_me_url(shared_line, workspace))
    |> assign(:selected_item, nil)
    |> assign(:selected_field, nil)
    |> assign(:item_values, %{})
    |> assign(:test_error, nil)
    |> assign(:data_ingestion_configured, data_ingestion_configured?(endpoint, catalog))
    |> assign(:cta_rules_configured, cta_rules != [])
    |> assign(:meta_configured, meta_configured)
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

  defp allow_variant_uploads(socket) do
    Enum.reduce(0..(@variant_slots - 1), socket, fn index, socket ->
      allow_upload(socket, :"variant_#{index}",
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 8,
        auto_upload: true,
        max_file_size: 8_000_000
      )
    end)
  end

  defp keep_latest_variant_uploads(socket) do
    Enum.reduce(0..(@variant_slots - 1), socket, fn index, socket ->
      name = :"variant_#{index}"

      case socket.assigns.uploads[name].entries do
        entries when length(entries) > 1 ->
          entries
          |> Enum.drop(-1)
          |> Enum.reduce(socket, fn entry, socket -> cancel_upload(socket, name, entry.ref) end)

        _ ->
          socket
      end
    end)
  end

  defp cancel_variant_upload(socket, %{"upload" => upload}) do
    name = String.to_existing_atom(variant_upload_name(upload))

    Enum.reduce(socket.assigns.uploads[name].entries, socket, fn entry, socket ->
      cancel_upload(socket, name, entry.ref)
    end)
  end

  defp cancel_variant_upload(socket, _slot), do: socket

  defp variant_upload_name(name) do
    name = to_string(name || "")
    allowed = Enum.map(0..(@variant_slots - 1), &"variant_#{&1}")
    if name in allowed, do: name, else: "variant_0"
  end

  defp attach_variant_images(socket, catalog_id, slots) do
    Enum.reduce_while(slots, {:ok, socket, []}, fn slot, {:ok, socket, acc} ->
      label = String.trim(slot["label"] || "")
      price = parse_price(slot["price"])

      if label == "" or is_nil(price) do
        {:cont, {:ok, socket, acc}}
      else
        case variant_image(socket, catalog_id, slot) do
          {:ok, socket, url} ->
            variant = %{"label" => label, "price" => price}
            variant = if url, do: Map.put(variant, "image_url", url), else: variant
            {:cont, {:ok, socket, acc ++ [variant]}}

          {:error, socket, message} ->
            {:halt, {:error, socket, message}}
        end
      end
    end)
  end

  defp variant_image(socket, catalog_id, slot) do
    name = String.to_existing_atom(variant_upload_name(slot["upload"]))

    case consume_images(socket, name, catalog_id) do
      {:ok, [url | _]} ->
        {:ok, socket, url}

      {:ok, []} ->
        url = if slot["clear_image"] == "true", do: nil, else: blank_to_nil(slot["image_url"])
        {:ok, socket, url}

      {:error, message} ->
        {:error, socket, message}
    end
  end

  defp empty_variant_slots, do: [blank_variant([])]

  defp blank_variant(existing) do
    used = MapSet.new(Enum.map(existing, & &1["upload"]))

    upload =
      Enum.find_value(0..(@variant_slots - 1), "variant_0", fn index ->
        name = "variant_#{index}"
        if name in used, do: nil, else: name
      end)

    %{"label" => "", "price" => "", "image_url" => "", "upload" => upload, "clear_image" => ""}
  end

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

  defp slots_from_item(item) do
    existing =
      item
      |> variants_of()
      |> Enum.with_index()
      |> Enum.map(fn {variant, index} ->
        %{
          "label" => variant["label"] || "",
          "price" => format_kes(variant["price"]),
          "image_url" => variant["image_url"] || "",
          "upload" => "variant_#{index}",
          "clear_image" => ""
        }
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
      |> Enum.with_index()
      |> Enum.map(fn {{_key, row}, index} ->
        %{
          "label" => row["label"] || "",
          "price" => row["price"] || "",
          "image_url" => row["image_url"] || "",
          "upload" => variant_upload_name(row["upload"] || "variant_#{index}"),
          "clear_image" => row["clear_image"] || ""
        }
      end)
      |> Enum.take(@variant_slots)

    if parsed == [], do: empty_variant_slots(), else: parsed
  end

  attr :slot, :map, required: true
  attr :index, :integer, required: true
  attr :uploads, :map, required: true
  attr :only, :boolean, required: true

  defp variant_row(assigns) do
    upload = assigns.uploads[String.to_existing_atom(assigns.slot["upload"])]
    entry = upload && List.last(upload.entries)
    has_photo = entry || (assigns.slot["image_url"] || "") != ""

    assigns = assign(assigns, upload: upload, entry: entry, has_photo: has_photo)

    ~H"""
    <div class="flex items-end gap-2">
      <input type="hidden" name={"item[variants][#{@index}][slot]"} value={@index} />
      <input type="hidden" name={"item[variants][#{@index}][upload]"} value={@slot["upload"]} />
      <input type="hidden" name={"item[variants][#{@index}][image_url]"} value={@slot["image_url"]} />
      <input
        :if={@slot["clear_image"] == "true"}
        type="hidden"
        name={"item[variants][#{@index}][clear_image]"}
        value="true"
      />
      <div class="soko-variant-photo">
        <label aria-label={"Photo for variant #{@index + 1}"}>
          <.live_img_preview :if={@entry} entry={@entry} />
          <img :if={!@entry && @slot["image_url"] != ""} src={@slot["image_url"]} alt="" />
          <.icon :if={!@has_photo} name="image" class="h-4 w-4" />
          <.live_file_input upload={@upload} />
        </label>
        <button
          :if={@has_photo}
          type="button"
          class="soko-variant-photo-clear"
          phx-click="clear_variant_photo"
          phx-value-index={@index}
          aria-label="Remove variant photo"
        >
          <.icon name="x" class="h-3 w-3" />
        </button>
      </div>
      <.input
        type="text"
        id={"variant-#{@index}-label"}
        name={"item[variants][#{@index}][label]"}
        value={@slot["label"]}
        label="Name"
        placeholder="EU 42"
        aria-required="true"
        class="min-w-0 flex-1"
      />
      <.input
        type="number"
        id={"variant-#{@index}-price"}
        name={"item[variants][#{@index}][price]"}
        value={@slot["price"]}
        label="KES"
        min="0"
        step="1"
        inputmode="numeric"
        aria-required="true"
        class="w-32 flex-none"
      />
      <.icon_button
        icon="x"
        class="mb-[3px]"
        phx-click="remove_variant"
        phx-value-index={@index}
        disabled={@only}
        aria-label="Remove variant"
      />
    </div>
    """
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
    names = [:cover, :extras] ++ Enum.map(0..(@variant_slots - 1), &:"variant_#{&1}")
    Enum.reduce(names, socket, &clear_upload/2)
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
end
