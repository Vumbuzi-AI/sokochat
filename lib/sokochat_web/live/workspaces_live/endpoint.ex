defmodule SokochatWeb.WorkspacesLive.Endpoint do
  use SokochatWeb, :live_view

  alias Ecto.Changeset
  alias Sokochat.Endpoints
  alias Sokochat.Endpoints.Endpoint
  alias Sokochat.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Data Endpoint")
     |> assign(:workspace, nil)
     |> assign(:endpoint, nil)
     |> assign(:preview_json, nil)
     |> assign(:preview_label, nil)
     |> assign(:test_error, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        endpoint = Endpoints.get_endpoint(workspace.id) || default_endpoint(workspace.id)

        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:endpoint, endpoint)
         |> assign(:preview_json, preview_json(endpoint.cached_data))
         |> assign(:preview_label, if(endpoint.cached_data, do: "Cached JSON preview", else: nil))
         |> assign(:test_error, nil)
         |> assign_form(Endpoints.change_endpoint(endpoint))}

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

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("submit", %{"endpoint" => endpoint_params}, socket) do
    case Map.get(endpoint_params, "action", "save") do
      "test" -> test_connection(socket, endpoint_params)
      _ -> save_endpoint(socket, endpoint_params)
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
         |> assign(:preview_json, preview_json(endpoint.cached_data))
         |> assign(:preview_label, if(endpoint.cached_data, do: "Cached JSON preview", else: nil))
         |> assign(:test_error, nil)
         |> assign_form(Endpoints.change_endpoint(endpoint))
         |> put_flash(:info, "Endpoint settings saved successfully.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
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
             |> assign_form(changeset)
             |> put_flash(:info, "Connection successful.")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:test_error, reason)
             |> assign_form(changeset)}
        end

      {:error, %Changeset{} = invalid_changeset} ->
        {:noreply, assign_form(socket, Map.put(invalid_changeset, :action, :validate))}
    end
  end

  defp assign_form(socket, %Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp current_endpoint(nil, workspace_id), do: default_endpoint(workspace_id)
  defp current_endpoint(endpoint, _workspace_id), do: endpoint

  defp default_endpoint(workspace_id) do
    %Endpoint{
      workspace_id: workspace_id,
      method: "GET",
      refresh_strategy: "on_demand",
      headers: %{}
    }
  end

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

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@workspace} class="mx-auto max-w-3xl space-y-6">
      <nav class="flex items-center gap-1.5 text-[13px] text-ink-faint">
        <.link navigate={~p"/workspaces"} class="transition hover:text-ink-muted">Workspaces</.link>
        <span>/</span>
        <.link navigate={~p"/workspaces/#{@workspace.id}"} class="transition hover:text-ink-muted">
          {@workspace.name}
        </.link>
        <span>/</span>
        <span class="text-ink-muted">Data Endpoint</span>
      </nav>

      <div class="overflow-hidden rounded-2xl border border-line bg-surface shadow-card">
        <div class="space-y-1.5 border-b border-line px-8 py-6">
          <h1 class="text-[22px] font-bold tracking-tight text-ink">Data Endpoint</h1>
          <p class="max-w-2xl text-sm leading-6 text-ink-muted">
            Connect the JSON endpoint the bot should read from so responses stay current with the business data.
          </p>
        </div>

        <div class="space-y-6 px-8 py-6">
          <div
            :if={@endpoint.last_fetched_at}
            class="flex items-center gap-2 rounded-lg border border-[#B7EBCF] bg-[#E8FFF3] px-4 py-2.5 text-[13px] font-medium text-brand-mid"
          >
            <.icon name="hero-check-circle-mini" class="h-4 w-4" />
            Last fetched: {last_fetched_label(@endpoint.last_fetched_at)}
          </div>

          <div
            :if={@test_error}
            role="alert"
            class="flex items-start gap-2 rounded-lg border border-[#FFCDD2] border-l-4 border-l-danger bg-danger-bg px-4 py-3 text-[13px] text-ink-muted"
          >
            <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-4 w-4 flex-none text-danger" />
            <span>{@test_error}</span>
          </div>

          <.simple_form for={@form} phx-change="validate" phx-submit="submit">
            <.input field={@form[:url]} label="URL" required />
            <.input
              field={@form[:method]}
              type="select"
              label="Method"
              options={[{"GET", "GET"}, {"POST", "POST"}]}
            />
            <.input
              field={@form[:headers_text]}
              type="textarea"
              label="Headers"
              placeholder="Authorization: Bearer token\nAccept: application/json"
            />

            <.input
              :if={@form[:method].value == "POST"}
              field={@form[:body_template]}
              type="textarea"
              label="Body template"
              placeholder={"{\"query\": \"{{query}}\"}"}
            />
            <p :if={@form[:method].value == "POST"} class="-mt-3 text-[13px] text-ink-muted">
              Use
              <code class="rounded bg-surface-alt px-1.5 py-0.5 font-mono text-xs text-ink">{"{{query}}"}</code>
              anywhere in the JSON body where the buyer's query should be inserted.
            </p>

            <.input
              field={@form[:refresh_strategy]}
              type="select"
              label="Refresh strategy"
              options={[
                {"On demand", "on_demand"},
                {"Every 60s", "poll_60s"},
                {"Every 5 min", "poll_300s"}
              ]}
            />

            <:actions>
              <.link
                navigate={~p"/workspaces/#{@workspace.id}"}
                class="mr-auto text-sm font-medium text-ink-muted transition hover:text-ink"
              >
                Back to dashboard
              </.link>
              <button
                type="submit"
                name="endpoint[action]"
                value="test"
                class="inline-flex items-center justify-center rounded-full border border-line bg-surface px-5 py-2.5 text-sm font-medium text-ink transition hover:bg-surface-alt"
              >
                Test connection
              </button>
              <.button name="endpoint[action]" value="save">Save endpoint</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>

      <details :if={@preview_json} open class="group overflow-hidden rounded-2xl border border-line bg-surface shadow-card">
        <summary class="flex cursor-pointer list-none items-center justify-between px-5 py-4">
          <span class="text-sm font-semibold text-ink">{@preview_label || "JSON preview"}</span>
          <.icon
            name="hero-chevron-down-mini"
            class="h-4 w-4 text-ink-faint transition group-open:rotate-180"
          />
        </summary>
        <pre class="code-panel overflow-x-auto px-5 py-4"><%= @preview_json %></pre>
      </details>
    </section>
    """
  end
end
