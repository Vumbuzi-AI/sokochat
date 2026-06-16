defmodule SokochatWeb.WorkspacesLive.Endpoint do
  use SokochatWeb, :live_view

  alias Ecto.Changeset
  alias Sokochat.Catalogs
  alias Sokochat.Catalogs.{Catalog, Field, Item}
  alias Sokochat.Endpoints
  alias Sokochat.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Data Ingestion")
     |> assign(:workspace, nil)
     |> assign(:endpoint, nil)
     |> assign(:catalog, nil)
     |> assign(:selected_item, nil)
     |> assign(:selected_field, nil)
     |> assign(:active_tab, "api")
     |> assign(:active_modal, nil)
     |> assign(:preview_json, nil)
     |> assign(:preview_label, nil)
     |> assign(:test_error, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        {:noreply, load_workspace_state(socket, workspace)}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  @impl true
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
         |> reload_workspace_state()}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, :catalog_form, Map.put(changeset, :action, :validate))}
    end
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
         |> reload_workspace_state(clear_selected_item: false)}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, :field_form, Map.put(changeset, :action, :validate))}
    end
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
    case Catalogs.upsert_item(socket.assigns.catalog, item_params) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Item saved.")
         |> assign(:active_modal, nil)
         |> reload_workspace_state()}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, :item_form, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :active_modal, nil)}
  end

  def handle_event("open_model", _params, socket) do
    {:noreply,
     socket
     |> assign_form(:catalog_form, Catalogs.change_catalog(socket.assigns.catalog))
     |> assign(:active_modal, :model)}
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
     |> reload_workspace_state(clear_selected_item: false)}
  end

  def handle_event("edit_item", %{"id" => id}, socket) do
    item = Catalogs.get_item!(socket.assigns.catalog.id, normalize_id(id))

    {:noreply,
     socket
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
     |> reload_workspace_state()}
  end

  def handle_event("new_item", _params, socket) do
    {:noreply,
     socket
     |> assign_new_item()
     |> assign(:active_modal, :item)}
  end

  defp assign_new_item(socket) do
    socket
    |> assign(:selected_item, nil)
    |> assign(:item_values, %{})
    |> assign_form(:item_form, Catalogs.change_item(blank_item(socket.assigns.catalog.id)))
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

  defp load_workspace_state(socket, workspace) do
    endpoint = Endpoints.get_endpoint(workspace.id) || default_endpoint(workspace.id)
    catalog = Catalogs.get_catalog(workspace.id) || default_catalog(workspace.id)

    socket
    |> assign(:workspace, workspace)
    |> assign(:endpoint, endpoint)
    |> assign(:catalog, catalog)
    |> assign(:selected_item, nil)
    |> assign(:selected_field, nil)
    |> assign(:item_values, %{})
    |> assign(:test_error, nil)
    |> assign_form(:endpoint_form, Endpoints.change_endpoint(endpoint))
    |> assign_form(:catalog_form, Catalogs.change_catalog(catalog))
    |> assign_form(:field_form, Catalogs.change_field(blank_field(catalog.id)))
    |> assign_form(:item_form, Catalogs.change_item(blank_item(catalog.id)))
    |> reload_preview()
  end

  defp reload_workspace_state(socket, opts \\ []) do
    selected_item? = Keyword.get(opts, :clear_selected_item, true)
    workspace = socket.assigns.workspace
    endpoint = socket.assigns.endpoint

    catalog = Catalogs.get_catalog(workspace.id) || default_catalog(workspace.id)

    socket =
      socket
      |> assign(:catalog, catalog)
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

    socket
    |> assign(:endpoint, Endpoints.get_endpoint(workspace.id) || endpoint)
    |> reload_preview()
  end

  defp reload_preview(socket) do
    preview_data =
      Catalogs.build_workspace_context(
        socket.assigns.workspace.id,
        endpoint_cached_data(socket.assigns.endpoint)
      )

    socket
    |> assign(:preview_json, preview_json(preview_data))
    |> assign(:preview_label, "Current ingestion context")
  end

  defp assign_form(socket, key, %Changeset{} = changeset) do
    assign(socket, key, to_form(changeset, as: form_name(key)))
  end

  defp form_name(:endpoint_form), do: :endpoint
  defp form_name(:catalog_form), do: :catalog
  defp form_name(:field_form), do: :field
  defp form_name(:item_form), do: :item

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
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
    %Field{
      catalog_id: catalog_id,
      field_type: "text",
      required: false,
      position: 0
    }
  end

  defp blank_item(catalog_id) do
    %Item{
      catalog_id: catalog_id,
      source: "manual",
      status: "active",
      metadata: %{}
    }
  end

  defp endpoint_cached_data(%{cached_data: cached_data}), do: cached_data
  defp endpoint_cached_data(_), do: nil

  defp preview_json(nil), do: nil

  defp preview_json(data) do
    Jason.encode_to_iodata!(data, pretty: true)
  end

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

  def render_custom_field(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <label class="block text-sm font-medium text-n900">{@field.label}</label>
      <div class="space-y-1.5">
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
          <% "url" -> %>
            <input
              type="url"
              name={"item[metadata][#{@field.key}]"}
              value={Map.get(@values, @field.key, "")}
              class="w-full rounded-lg border border-n300 bg-n50 px-3 py-2 text-sm text-n900 shadow-sm outline-none transition focus:border-primary"
            />
          <% "image_url" -> %>
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
      </div>
      <p :if={@field.help_text} class="text-xs leading-5 text-n400">{@field.help_text}</p>
    </div>
    """
  end

  defp canonical_item_field?(key), do: key in Catalogs.canonical_item_keys()

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
        "flex items-center gap-2 border-b-2 px-1 py-4 text-sm font-medium transition",
        (@active == @tab && "border-primary text-n900") ||
          "border-transparent text-n400 hover:text-n900"
      ]}
    >
      <.icon name={@icon} class="h-4 w-4" />
      {@label}
    </button>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :width, :string, default: "max-w-lg"
  slot :inner_block, required: true

  defp modal_shell(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-n900/40 p-4 sm:p-6 lg:py-10"
      phx-window-keydown="close_modal"
      phx-key="escape"
    >
      <div class="absolute inset-0" phx-click="close_modal" aria-hidden="true"></div>
      <div class={[
        "relative w-full rounded-2xl border border-n300 bg-white shadow-[0_20px_60px_rgba(0,0,0,0.18)]",
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
        <div class="px-6 py-5">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  defp icon_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "rounded-lg border border-n300 bg-white p-2 transition",
        (@variant == "danger" && "text-danger hover:bg-danger-bg") ||
          "text-n400 hover:bg-n200 hover:text-n900"
      ]}
      {@rest}
    >
      <.icon name={@icon} class="h-4 w-4" />
    </button>
    """
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :custom_fields,
        Enum.reject(assigns.catalog.fields || [], fn field -> canonical_item_field?(field.key) end)
      )

    ~H"""
    <section :if={@workspace} class="mx-auto max-w-5xl space-y-6">
      <nav class="flex items-center gap-1.5 text-[13px] text-n500">
        <.link navigate={~p"/workspaces"} class="transition hover:text-n400">Workspaces</.link>
        <span>/</span>
        <.link navigate={~p"/workspaces/#{@workspace.id}"} class="transition hover:text-n400">
          {@workspace.name}
        </.link>
        <span>/</span>
        <span class="text-n400">Data Ingestion</span>
      </nav>

      <div class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]">
        <div class="space-y-1.5 border-b border-n300 px-8 py-6">
          <h1 class="text-[22px] font-bold tracking-tight text-n900">Data Ingestion</h1>
          <p class="max-w-3xl text-sm leading-6 text-n400">
            Connect a JSON API, define a manual catalog model, and add items directly in
            the workspace. The AI will read both sources as one shared business context.
          </p>
        </div>

        <div class="flex gap-6 border-b border-n300 px-8">
          <.tab_button tab="api" active={@active_tab} label="JSON API" icon="hero-bolt-mini" />
          <.tab_button
            tab="manual"
            active={@active_tab}
            label="Manual Catalog"
            icon="hero-squares-2x2-mini"
          />
          <.tab_button
            tab="preview"
            active={@active_tab}
            label="AI Context"
            icon="hero-code-bracket-mini"
          />
        </div>

        <div class="px-8 py-6">
          <%!-- JSON API tab --%>
          <div :if={@active_tab == "api"} class="max-w-2xl space-y-6">
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
              class="flex items-start gap-2 rounded-lg border border-[#FFCDD2] border-l-4 border-l-danger bg-danger-bg px-4 py-3 text-[13px] text-n400"
            >
              <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-4 w-4 flex-none text-danger" />
              <span>{@test_error}</span>
            </div>

            <div class="space-y-1.5">
              <h2 class="text-[18px] font-semibold text-n900">JSON API</h2>
              <p class="text-sm leading-6 text-n400">
                Keep an external feed connected for shops that already expose inventory or
                product data through an API.
              </p>
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
              <p :if={@endpoint_form[:method].value == "POST"} class="-mt-3 text-[13px] text-n400">
                Use
                <code class="rounded bg-n200 px-1.5 py-0.5 font-mono text-xs text-n900">
                  {"{{query}}"}
                </code>
                anywhere in the JSON body where the buyer's query should be inserted.
              </p>

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
                  class="inline-flex items-center justify-center rounded-full border border-n300 bg-n50 px-5 py-2.5 text-sm font-medium text-n900 transition hover:bg-n200"
                >
                  Test connection
                </button>
                <.button name="endpoint[action]" value="save">Save endpoint</.button>
              </:actions>
            </.simple_form>
          </div>

          <%!-- Manual catalog tab --%>
          <div :if={@active_tab == "manual"}>
            <div
              :if={!@catalog.id}
              class="flex flex-col items-center justify-center gap-4 rounded-2xl border border-dashed border-n300 bg-white px-6 py-14 text-center"
            >
              <span class="flex h-12 w-12 items-center justify-center rounded-full bg-primary-light text-primary">
                <.icon name="hero-squares-2x2" class="h-6 w-6" />
              </span>
              <div class="space-y-1.5">
                <h2 class="text-[18px] font-semibold text-n900">Set up your catalog model</h2>
                <p class="mx-auto max-w-md text-sm leading-6 text-n400">
                  Define a reusable schema for this shop, then add fields and items one by one
                  without touching JSON.
                </p>
              </div>
              <.button phx-click="open_model">Set up catalog model</.button>
            </div>

            <div :if={@catalog.id} class="space-y-6">
              <div class="flex flex-wrap items-start justify-between gap-4 rounded-2xl border border-n300 bg-white p-6 shadow-sm">
                <div class="space-y-1.5">
                  <p class="text-[11px] font-semibold uppercase tracking-wide text-n400">
                    Catalog model
                  </p>
                  <h2 class="text-[18px] font-semibold text-n900">{@catalog.name}</h2>
                  <p class="text-sm text-n400">
                    Items labelled as
                    <span class="font-medium text-n900">{@catalog.entity_label}</span>
                  </p>
                  <p
                    :if={@catalog.context_notes not in [nil, ""]}
                    class="max-w-xl text-sm leading-6 text-n400"
                  >
                    {@catalog.context_notes}
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="open_model"
                  class="inline-flex items-center gap-1.5 rounded-full border border-n300 bg-n50 px-4 py-2 text-sm font-medium text-n900 transition hover:bg-n200"
                >
                  <.icon name="hero-pencil-square-mini" class="h-4 w-4" /> Edit model
                </button>
              </div>

              <div class="rounded-2xl border border-n300 bg-white p-6 shadow-sm">
                <div class="flex flex-wrap items-start justify-between gap-3">
                  <div class="space-y-1.5">
                    <h2 class="text-[18px] font-semibold text-n900">Fields</h2>
                    <p class="text-sm leading-6 text-n400">
                      Custom fields for this catalog. Core fields like title, price, URL and
                      image URL are already built in.
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="new_field"
                    class="inline-flex items-center gap-1.5 rounded-full border border-n300 bg-n50 px-4 py-2 text-sm font-medium text-n900 transition hover:bg-n200"
                  >
                    <.icon name="hero-plus-mini" class="h-4 w-4" /> Add field
                  </button>
                </div>

                <div class="mt-5 space-y-3">
                  <div
                    :for={field <- @catalog.fields || []}
                    class="flex items-start justify-between gap-3 rounded-lg border border-n300 bg-n200 px-4 py-3"
                  >
                    <div>
                      <p class="font-medium text-n900">{field.label}</p>
                      <p class="text-xs text-n400">
                        <span class="font-mono">{field.key}</span>
                        · {field.field_type}<span :if={field.required}> · required</span>
                      </p>
                      <p :if={field.help_text} class="mt-1 text-xs leading-5 text-n400">
                        {field.help_text}
                      </p>
                    </div>
                    <div class="flex flex-none items-center gap-2">
                      <.icon_button
                        icon="hero-pencil-square-mini"
                        variant="default"
                        rest={%{"phx-click" => "edit_field", "phx-value-id" => field.id}}
                      />
                      <.icon_button
                        icon="hero-trash-mini"
                        variant="danger"
                        rest={
                          %{
                            "phx-click" => "delete_field",
                            "phx-value-id" => field.id,
                            "data-confirm" => "Remove this field from the model?"
                          }
                        }
                      />
                    </div>
                  </div>

                  <p :if={@catalog.fields == []} class="text-sm text-n400">
                    No extra fields yet. Add one to start shaping the manual form.
                  </p>
                </div>
              </div>

              <div class="rounded-2xl border border-n300 bg-white p-6 shadow-sm">
                <div class="flex flex-wrap items-start justify-between gap-3">
                  <div class="space-y-1.5">
                    <h2 class="text-[18px] font-semibold text-n900">
                      Items
                      <span class="ml-1 text-sm font-normal text-n400">
                        ({length(@catalog.items || [])})
                      </span>
                    </h2>
                    <p class="text-sm leading-6 text-n400">
                      Curated items the AI can use alongside JSON API data.
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="new_item"
                    class="inline-flex items-center gap-1.5 rounded-full bg-primary px-4 py-2 text-sm font-medium text-white transition hover:opacity-90"
                  >
                    <.icon name="hero-plus-mini" class="h-4 w-4" /> New item
                  </button>
                </div>

                <div class="mt-5 space-y-3">
                  <div
                    :for={item <- @catalog.items || []}
                    class="rounded-lg border border-n300 bg-n200 px-4 py-3"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div class="space-y-1">
                        <p class="font-medium text-n900">{item.title}</p>
                        <p class="text-xs text-n400">
                          {item.currency || "No currency"}{if item.price,
                            do: " · #{item.price}",
                            else: ""}<span :if={item.status}> · {item.status}</span>
                        </p>
                      </div>
                      <div class="flex flex-none items-center gap-2">
                        <.icon_button
                          icon="hero-pencil-square-mini"
                          variant="default"
                          rest={%{"phx-click" => "edit_item", "phx-value-id" => item.id}}
                        />
                        <.icon_button
                          icon="hero-trash-mini"
                          variant="danger"
                          rest={
                            %{
                              "phx-click" => "delete_item",
                              "phx-value-id" => item.id,
                              "data-confirm" => "Delete this item?"
                            }
                          }
                        />
                      </div>
                    </div>
                    <p :if={item.description} class="mt-2 text-sm leading-6 text-n400">
                      {item.description}
                    </p>
                    <div :if={map_size(item.metadata || %{}) > 0} class="mt-3 flex flex-wrap gap-2">
                      <span
                        :for={{key, value} <- item.metadata || %{}}
                        class="rounded-full bg-white px-2.5 py-0.5 text-[11px] font-medium text-n400"
                      >
                        {key}: {value}
                      </span>
                    </div>
                  </div>

                  <p :if={@catalog.items == []} class="text-sm text-n400">
                    No items added yet. Use “New item” to create the first one.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%!-- AI context preview tab --%>
          <div :if={@active_tab == "preview"} class="space-y-3">
            <div class="space-y-1.5">
              <h2 class="text-[18px] font-semibold text-n900">AI context preview</h2>
              <p class="text-sm leading-6 text-n400">
                {@preview_label || "The shared business context"} the assistant reads for this
                workspace.
              </p>
            </div>
            <div
              :if={@preview_json}
              class="overflow-hidden rounded-2xl border border-n300 bg-n50 shadow-[0_8px_24px_rgba(0,0,0,0.05)]"
            >
              <pre class="code-panel overflow-x-auto px-5 py-4"><%= @preview_json %></pre>
            </div>
            <p :if={!@preview_json} class="text-sm text-n400">
              Nothing to preview yet. Connect an API or add catalog items first.
            </p>
          </div>
        </div>
      </div>

      <%!-- Catalog model modal --%>
      <.modal_shell
        :if={@active_modal == :model}
        title="Catalog model"
        subtitle="Define the reusable schema for this shop."
      >
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
            placeholder="Tell the AI what the catalog means, what fields matter, and how to read them."
          />

          <:actions>
            <button
              type="button"
              phx-click="close_modal"
              class="inline-flex items-center justify-center rounded-full border border-n300 bg-n50 px-5 py-2.5 text-sm font-medium text-n900 transition hover:bg-n200"
            >
              Cancel
            </button>
            <.button>Save model</.button>
          </:actions>
        </.simple_form>
      </.modal_shell>

      <%!-- Field modal --%>
      <.modal_shell
        :if={@active_modal == :field}
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
            field={@field_form[:label]}
            label="Label"
            placeholder="Color, Size, Stock status"
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
              class="inline-flex items-center justify-center rounded-full border border-n300 bg-n50 px-5 py-2.5 text-sm font-medium text-n900 transition hover:bg-n200"
            >
              Cancel
            </button>
            <.button>{if @selected_field, do: "Update field", else: "Add field"}</.button>
          </:actions>
        </.simple_form>
      </.modal_shell>

      <%!-- Item modal --%>
      <.modal_shell
        :if={@active_modal == :item}
        width="max-w-2xl"
        title={if @selected_item, do: "Edit item", else: "New item"}
        subtitle="Custom fields are saved separately and included in the AI context."
      >
        <.simple_form for={@item_form} phx-change="validate_item" phx-submit="save_item">
          <input type="hidden" name="item[id]" value={(@selected_item && @selected_item.id) || ""} />

          <div class="grid gap-4 sm:grid-cols-2">
            <.input field={@item_form[:title]} label="Title" required />
            <.input field={@item_form[:external_id]} label="External ID" />
            <.input field={@item_form[:price]} type="number" step="any" label="Price" />
            <.input field={@item_form[:currency]} label="Currency" placeholder="KES, USD, etc." />
            <.input field={@item_form[:url]} type="url" label="URL" />
            <.input field={@item_form[:image_url]} type="url" label="Image URL" />
            <.input field={@item_form[:phone_number]} label="Phone number" />
            <.input field={@item_form[:whatsapp_number]} label="WhatsApp number" />
            <.input field={@item_form[:sort_order]} type="number" label="Sort order" />
            <.input
              field={@item_form[:status]}
              type="select"
              label="Status"
              options={[
                {"Active", "active"},
                {"Draft", "draft"},
                {"Archived", "archived"}
              ]}
            />
            <.input
              field={@item_form[:source]}
              type="select"
              label="Source"
              options={[
                {"Manual", "manual"},
                {"API", "api"},
                {"Import", "import"}
              ]}
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
              <.render_custom_field
                :for={field <- @custom_fields}
                field={field}
                values={@item_values}
              />
            </div>
          </div>

          <:actions>
            <button
              type="button"
              phx-click="close_modal"
              class="inline-flex items-center justify-center rounded-full border border-n300 bg-n50 px-5 py-2.5 text-sm font-medium text-n900 transition hover:bg-n200"
            >
              Cancel
            </button>
            <.button>{if @selected_item, do: "Update item", else: "Add item"}</.button>
          </:actions>
        </.simple_form>
      </.modal_shell>
    </section>
    """
  end
end
