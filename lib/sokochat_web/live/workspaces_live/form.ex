defmodule SokochatWeb.WorkspacesLive.Form do
  use SokochatWeb, :live_view

  alias Ecto.Changeset
  alias Sokochat.Storage.Images
  alias Sokochat.Workspaces
  alias Sokochat.Workspaces.Website
  alias Sokochat.Workspaces.Workspace

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:workspace, nil)
      |> assign_new_workspace()
      |> allow_upload(:logo,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 2,
        auto_upload: true,
        max_file_size: 8_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, %{assigns: %{live_action: :edit}} = socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> assign(:page_title, "Edit workspace")
         |> assign(:workspace, workspace)
         |> assign(:leave_path, leave_path(workspace, socket.assigns.current_user))
         |> assign_form(Workspaces.change_workspace(workspace))}

      :error ->
        {:noreply, redirect_to_index(socket)}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(:page_title, "New workspace") |> assign_new_workspace()}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: socket.assigns.leave_path)}
  end

  def handle_event("validate", %{"workspace" => workspace_params}, socket) do
    changeset =
      socket.assigns.workspace
      |> current_workspace()
      |> Workspaces.change_workspace(workspace_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> keep_latest_logo() |> assign_form(changeset)}
  end

  def handle_event(
        "save",
        %{"workspace" => workspace_params},
        %{assigns: %{live_action: :new}} = socket
      ) do
    case Workspaces.create_workspace(workspace_params, socket.assigns.current_user.id) do
      {:ok, workspace} ->
        save_details(socket, workspace, workspace_params["website_url"], :created)

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    case Workspaces.update_workspace(socket.assigns.workspace, workspace_params) do
      {:ok, workspace} ->
        save_details(socket, workspace, nil, :updated)

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_details(socket, workspace, website_url, kind) do
    case attach_logo(socket, workspace) do
      {:ok, socket, workspace} ->
        {workspace, info, error} = maybe_fill_ai_content(workspace, website_url, kind)

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> maybe_error(error)
         |> push_navigate(to: ~p"/workspaces/#{workspace.id}")}

      {:error, socket, message} ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> push_navigate(to: ~p"/workspaces/#{workspace.id}")}
    end
  end

  defp maybe_fill_ai_content(workspace, url, :created) when is_binary(url) do
    url = String.trim(url)

    if url == "" do
      {workspace, "Workspace created.", nil}
    else
      case Website.brief(url) do
        {:ok, brief} ->
          case Workspaces.update_workspace(workspace, %{"ai_instructions" => brief}) do
            {:ok, updated} ->
              {updated, "Workspace created. AI content is filled from your website.", nil}

            {:error, _changeset} ->
              {workspace, "Workspace created.", nil}
          end

        {:error, message} ->
          {workspace, "Workspace created.", message}
      end
    end
  end

  defp maybe_fill_ai_content(workspace, _url, :created),
    do: {workspace, "Workspace created.", nil}

  defp maybe_fill_ai_content(workspace, _url, :updated),
    do: {workspace, "Workspace updated.", nil}

  defp maybe_error(socket, nil), do: socket
  defp maybe_error(socket, message), do: put_flash(socket, :error, message)

  defp attach_logo(socket, workspace) do
    results =
      consume_uploaded_entries(socket, :logo, fn %{path: path}, entry ->
        extension = Path.extname(entry.client_name || "") |> String.downcase()
        key = "workspaces/#{workspace.id}/logo-#{System.unique_integer([:positive])}#{extension}"

        case Images.put_file(path, key, entry.client_type) do
          {:ok, url} -> {:ok, url}
          {:error, reason} -> {:postpone, {:error, logo_error(reason)}}
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, message} ->
        {:error, socket, message}

      nil ->
        case Enum.find(results, &is_binary/1) do
          url when is_binary(url) ->
            case Workspaces.update_workspace(workspace, %{"logo_url" => url}) do
              {:ok, workspace} -> {:ok, socket, workspace}
              {:error, _changeset} -> {:error, socket, "The logo could not be saved."}
            end

          _ ->
            {:ok, socket, workspace}
        end
    end
  rescue
    ArgumentError ->
      {:error, socket, "Wait for the logo upload to finish, then save again."}
  end

  defp logo_error(reason) when is_binary(reason), do: reason

  defp keep_latest_logo(socket) do
    case socket.assigns.uploads.logo.entries do
      entries when length(entries) > 1 ->
        entries
        |> Enum.drop(-1)
        |> Enum.reduce(socket, fn entry, socket -> cancel_upload(socket, :logo, entry.ref) end)

      _ ->
        socket
    end
  end

  defp assign_new_workspace(socket) do
    workspace = %Workspace{language: "both"}

    socket
    |> assign(:workspace, workspace)
    |> assign(:leave_path, leave_path(workspace, socket.assigns.current_user))
    |> assign_form(Workspaces.change_workspace(workspace))
  end

  defp assign_form(socket, %Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp current_workspace(nil), do: %Workspace{language: "both"}
  defp current_workspace(workspace), do: workspace

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp redirect_to_index(socket) do
    socket
    |> put_flash(:error, "Workspace not found.")
    |> push_navigate(to: ~p"/workspaces")
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :logo_entry, List.last(assigns.uploads.logo.entries))

    ~H"""
    <.stage_page title={@page_title} current_user={@current_user} back={@leave_path} center>
      <div class="w-full max-w-[560px] overflow-hidden rounded-soko-20 border border-soko-line bg-soko-white">
        <.simple_form for={@form} phx-change="validate" phx-submit="save" multipart class="!gap-0">
          <div class="flex flex-col gap-5 p-6 sm:p-7">
            <div class="flex flex-col gap-2">
              <h1 class="soko-heading text-[28px]">{@page_title}</h1>
              <p class="text-sm text-soko-ink-2">
                <%= if @live_action == :new do %>
                  Name the shop, add a logo if you have one, and paste the website. Sokochat reads the site and writes the AI content.
                <% else %>
                  Name, logo and website. AI content lives on the shop page.
                <% end %>
              </p>
            </div>
            <.input field={@form[:name]} label="Name" placeholder="Soko Shoes" required />
            <div class="flex flex-col gap-2">
              <p class="soko-label">Logo <span class="soko-hint">Optional</span></p>
              <label class="soko-logo-pick">
                <span>
                  <.live_img_preview :if={@logo_entry} entry={@logo_entry} />
                  <img :if={!@logo_entry && @workspace.logo_url} src={@workspace.logo_url} alt="" />
                  <.icon :if={!@logo_entry && !@workspace.logo_url} name="image" class="h-4 w-4" />
                </span>
                <span>
                  <strong>Add a logo</strong>
                  <span class="soko-hint">JPG, PNG or WEBP.</span>
                </span>
                <.live_file_input upload={@uploads.logo} />
              </label>
              <p :for={error <- upload_errors(@uploads.logo)} class="soko-error">
                {upload_error(error)}
              </p>
            </div>
            <.input
              field={@form[:website_url]}
              type="url"
              label="Website"
              placeholder="https://sokoshoes.co.ke"
              hint={
                if @live_action == :new,
                  do: "Optional. We use it to fill AI content on the shop page.",
                  else: "Optional."
              }
            />
            <.input
              :if={@live_action == :edit}
              field={@form[:language]}
              type="select"
              label="Languages"
              options={[
                {"English and Swahili", "both"},
                {"English only", "en"},
                {"Swahili only", "sw"}
              ]}
            />
          </div>
          <div class="flex justify-end gap-2 border-t border-soko-divider px-6 py-4 sm:px-7">
            <.button type="button" tone="secondary" phx-click="cancel">Cancel</.button>
            <.button phx-disable-with="Saving">
              {if @live_action == :new, do: "Create workspace", else: "Save changes"}
            </.button>
          </div>
        </.simple_form>
      </div>
    </.stage_page>
    """
  end

  defp upload_error(:too_large), do: "Logo must be under 8 MB."
  defp upload_error(:not_accepted), do: "Use a JPG, PNG or WEBP."
  defp upload_error(:too_many_files), do: "Add one logo."
  defp upload_error(_error), do: "The logo could not be added."

  defp leave_path(%Workspace{id: id}, _user) when not is_nil(id), do: ~p"/workspaces/#{id}"

  defp leave_path(_workspace, user) do
    case Workspaces.get_home_workspace(user.id) do
      nil -> ~p"/users/settings"
      workspace -> ~p"/workspaces/#{workspace.id}"
    end
  end
end
