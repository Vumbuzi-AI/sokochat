defmodule SokochatWeb.PlaygroundLive do
  use SokochatWeb, :live_view

  import SokochatWeb.PlaygroundChat
  import SokochatWeb.WorkspaceShell

  alias Sokochat.Conversations
  alias Sokochat.Conversations.Dispatcher
  alias Sokochat.Conversations.Message
  alias Sokochat.Endpoints
  alias Sokochat.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Playground")
     |> assign(:workspace, nil)
     |> assign(:endpoint, nil)
     |> assign(:conversation, nil)
     |> assign(:phone_number, nil)
     |> assign(:subscribed_workspace_id, nil)
     |> assign(:message_ids, MapSet.new())
     |> assign(:pending_user_message, nil)
     |> assign(:assistant_pending, false)
     |> assign(:active_dispatch_ref, nil)
     |> assign_message_form("")
     |> stream(:messages, []), layout: false}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        phone_number = Conversations.playground_phone_number(workspace.id)
        conversation = Conversations.get_conversation(workspace.id, phone_number, :playground)
        messages = if conversation, do: Conversations.list_messages(conversation.id), else: []
        endpoint = Endpoints.get_endpoint(workspace.id)

        socket =
          socket
          |> maybe_subscribe(workspace.id)
          |> assign(:workspace, workspace)
          |> assign(:endpoint, endpoint)
          |> assign(:conversation, conversation)
          |> assign(:phone_number, phone_number)
          |> assign(:message_ids, message_ids(messages))
          |> stream(:messages, messages, reset: true)

        {:noreply, socket}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  @impl true
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

    {:noreply,
     socket
     |> assign(:conversation, nil)
     |> assign(:message_ids, MapSet.new())
     |> assign(:pending_user_message, nil)
     |> assign(:assistant_pending, false)
     |> assign(:active_dispatch_ref, nil)
     |> assign_message_form("")
     |> stream(:messages, [], reset: true)}
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
    if socket.assigns.active_dispatch_ref == dispatch_ref do
      {:noreply,
       socket
       |> assign(:pending_user_message, nil)
       |> assign(:assistant_pending, false)
       |> assign(:active_dispatch_ref, nil)
       |> put_flash(:error, format_error(reason))}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:dispatch_message, dispatch_ref}, {:exit, reason}, socket) do
    if socket.assigns.active_dispatch_ref == dispatch_ref do
      {:noreply,
       socket
       |> assign(:pending_user_message, nil)
       |> assign(:assistant_pending, false)
       |> assign(:active_dispatch_ref, nil)
       |> put_flash(:error, format_error(reason))}
    else
      {:noreply, socket}
    end
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
      {:noreply,
       socket
       |> assign(:conversation, nil)
       |> assign(:message_ids, MapSet.new())
       |> assign(:pending_user_message, nil)
       |> assign(:assistant_pending, false)
       |> assign(:active_dispatch_ref, nil)
       |> stream(:messages, [], reset: true)}
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

  @impl true
  def render(assigns) do
    ~H"""
    <.shell
      :if={@workspace}
      workspace={@workspace}
      current_user={@current_user}
      tab={:playground}
      title="Playground"
      flash={@flash}
    >
      <:actions>
        <.button type="button" variant="secondary" phx-click="clear_chat">
          Clear chat
        </.button>
      </:actions>
      <div class="wa-stage">
        <div class="wa-phone">
          <div class="phone-screen">
            <div class="ios-status">
              <span class="ios-time">9:41</span>
              <span class="dynamic-island"><span></span></span>
              <span class="ios-indicators">
                <svg class="ios-cellular" viewBox="0 0 20 14" fill="currentColor" aria-hidden="true">
                  <rect x="0" y="9" width="3" height="5" rx=".6" /><rect
                    x="5"
                    y="6"
                    width="3"
                    height="8"
                    rx=".6"
                  /><rect x="10" y="3" width="3" height="11" rx=".6" /><rect
                    x="15"
                    width="3"
                    height="14"
                    rx=".6"
                  />
                </svg>
                <svg class="ios-wifi" viewBox="0 0 20 15" fill="currentColor" aria-hidden="true">
                  <path d="M0 4a16 16 0 0 1 20 0l-2.4 2.5a12.5 12.5 0 0 0-15.2 0Zm4.1 4.2a9 9 0 0 1 11.8 0l-2.4 2.5a5.5 5.5 0 0 0-7 0Zm3.5 3.6a3.5 3.5 0 0 1 4.8 0L10 15Z" />
                </svg>
                <svg class="ios-battery" viewBox="0 0 30 14" aria-hidden="true">
                  <rect
                    x=".5"
                    y="1"
                    width="25"
                    height="12"
                    rx="3"
                    fill="none"
                    stroke="currentColor"
                    opacity=".4"
                  /><rect x="2.5" y="3" width="21" height="8" rx="1.5" fill="currentColor" /><path
                    d="M27 4v6c2 0 2-6 0-6"
                    fill="currentColor"
                    opacity=".4"
                  />
                </svg>
              </span>
            </div>

            <div
              id="playground-scroll-region"
              phx-hook="PlaygroundScroll"
              data-message-count={MapSet.size(@message_ids)}
              data-pending={to_string(not is_nil(@pending_user_message) or @assistant_pending)}
              class="wa-chat"
            >
              <span class="wa-date">Today</span>
              <div id="playground-messages" phx-update="stream" class="wa-messages">
                <div :for={{dom_id, message} <- @streams.messages} id={dom_id}>
                  <.message_bubble message={message} assistant_pending={@assistant_pending} />
                </div>
              </div>

              <div :if={@pending_user_message} class="wa-turn wa-turn-out wa-pending">
                <div class="wa-bubble wa-outgoing">
                  <span class="wa-copy">{@pending_user_message.content}</span>
                  <span class="wa-meta">{message_time(@pending_user_message.inserted_at)}</span>
                </div>
              </div>

              <div :if={@assistant_pending} class="wa-turn">
                <div class="wa-bubble wa-incoming" aria-label="Typing">
                  <span class="wa-dots" aria-hidden="true">
                    <span></span><span></span><span></span>
                  </span>
                </div>
              </div>
            </div>

            <div class="wa-bottom-chrome">
              <.form for={@message_form} as={:playground} phx-submit="send_message" class="wa-compose">
                <label class="compose-field">
                  <input
                    type="text"
                    name={@message_form[:message].name}
                    id={@message_form[:message].id}
                    value={@message_form[:message].value}
                    autocomplete="off"
                    aria-label="Message"
                    disabled={@assistant_pending}
                  />
                </label>
                <button
                  type="submit"
                  aria-label="Send message"
                  disabled={@assistant_pending}
                  class="wa-send"
                >
                  <.wa_glyph name="microphone" />
                </button>
              </.form>
              <div class="ios-bottom-safe">
                <div class="home-indicator"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.shell>
    """
  end

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

  defp maybe_subscribe(socket, workspace_id) do
    if connected?(socket) and socket.assigns.subscribed_workspace_id != workspace_id do
      Conversations.subscribe_playground(workspace_id)
      Endpoints.subscribe_workspace(workspace_id)
      assign(socket, :subscribed_workspace_id, workspace_id)
    else
      socket
    end
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
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
end
