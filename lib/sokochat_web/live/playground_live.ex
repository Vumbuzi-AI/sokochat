defmodule SokochatWeb.PlaygroundLive do
  use SokochatWeb, :live_view

  import SokochatWeb.PlaygroundChat

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
     |> stream(:messages, [])}
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
    <section :if={@workspace} class="mx-auto max-w-6xl space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <nav class="flex items-center gap-1.5 text-[13px] text-n500">
            <.link navigate={~p"/workspaces"} class="transition hover:text-n400">
              Workspaces
            </.link>
            <span>/</span>
            <.link navigate={~p"/workspaces/#{@workspace.id}"} class="transition hover:text-n400">
              {@workspace.name}
            </.link>
            <span>/</span>
            <span class="text-n400">Playground</span>
          </nav>
          <h1 class="mt-1 text-[22px] font-bold tracking-tight text-n900">Playground</h1>
        </div>
        <.link
          navigate={~p"/workspaces/#{@workspace.id}"}
          class="inline-flex h-9 items-center rounded-full border border-n300 bg-n50 px-4 text-sm font-medium text-n900 transition hover:bg-n200"
        >
          Back to dashboard
        </.link>
      </div>

      <div class="flex h-[calc(100vh-180px)] flex-col overflow-hidden rounded-2xl border border-n300 bg-white shadow-[0_8px_24px_rgba(0,0,0,0.05)]">
        <div class="flex items-center gap-3 rounded-t-2xl bg-gradient-to-br from-primary to-primary px-5 py-3.5">
          <div class="relative">
            <span class="flex h-9 w-9 items-center justify-center rounded-full bg-white text-[15px] font-semibold text-primary">
              {String.upcase(String.first(@workspace.name))}
            </span>
            <span class="absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-primary bg-primary-light">
            </span>
          </div>
          <div class="min-w-0 flex-1">
            <p class="truncate text-[15px] font-semibold text-white">{@workspace.name}</p>
            <p class="truncate text-xs text-white/60">Connected to: {endpoint_label(@endpoint)}</p>
          </div>
          <button
            type="button"
            phx-click="clear_chat"
            aria-label="Clear chat"
            title="Clear chat"
            class="inline-flex h-8 w-8 items-center justify-center rounded-full text-white/60 transition hover:bg-white/10 hover:text-white"
          >
            <.icon name="hero-trash-mini" class="h-4 w-4" />
          </button>
        </div>

        <div
          id="playground-scroll-region"
          phx-hook="PlaygroundScroll"
          data-message-count={MapSet.size(@message_ids)}
          data-pending={to_string(not is_nil(@pending_user_message) or @assistant_pending)}
          class="flex-1 overflow-y-auto px-4 py-4"
          style="background-color: #ECE5DD; background-image: radial-gradient(circle, rgba(0,0,0,0.04) 1px, transparent 1px); background-size: 20px 20px;"
        >
          <div
            :if={
              MapSet.size(@message_ids) == 0 and is_nil(@pending_user_message) and
                not @assistant_pending
            }
            id="playground-empty"
            class="flex h-full flex-col items-center justify-center text-center"
          >
            <.icon name="hero-chat-bubble-left-right" class="h-12 w-12 text-n500/40" />
            <p class="mt-3 text-sm text-n400">Send a message to test your bot</p>
            <p class="mt-1 text-[13px] text-n500">
              Responses mirror the live WhatsApp experience.
            </p>
          </div>

          <div id="playground-messages" phx-update="stream" class="space-y-2.5">
            <div :for={{dom_id, message} <- @streams.messages} id={dom_id}>
              <.message_bubble message={message} assistant_pending={@assistant_pending} />
            </div>
          </div>

          <div :if={@pending_user_message} class="mt-2.5">
            <div class="flex justify-end">
              <div class="max-w-[72%] space-y-1">
                <div class="rounded-[12px_12px_0_12px] bg-primary-light px-3.5 py-2.5 text-[15px] text-n900 opacity-80">
                  <p class="whitespace-pre-wrap break-words leading-6">
                    {@pending_user_message.content}
                  </p>
                  <div class="mt-1 flex items-center justify-end gap-2 text-[11px] text-n500">
                    <span>Sending...</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div :if={@assistant_pending} class="mt-2.5 flex justify-start animate-bubble-in">
            <div class="max-w-[78%] rounded-[12px_12px_12px_0] bg-white px-3.5 py-3 text-n900 shadow-[0_1px_2px_rgba(0,0,0,0.08)]">
              <div class="flex items-center gap-2 text-sm text-n400">
                <span class="flex items-center gap-1" aria-hidden="true">
                  <span class="h-2 w-2 rounded-full bg-primary animate-pulse-dot"></span>
                  <span class="h-2 w-2 rounded-full bg-primary animate-pulse-dot"></span>
                  <span class="h-2 w-2 rounded-full bg-primary animate-pulse-dot"></span>
                </span>
                <span>Bot is typing...</span>
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2.5 rounded-b-2xl border-t border-n300 bg-[#F0F2F5] px-4 py-2.5">
          <.form
            for={@message_form}
            as={:playground}
            phx-submit="send_message"
            class="flex flex-1 items-center gap-2.5"
          >
            <input
              type="text"
              name={@message_form[:message].name}
              id={@message_form[:message].id}
              value={@message_form[:message].value}
              placeholder="Type a message..."
              autocomplete="off"
              disabled={@assistant_pending}
              class="flex-1 rounded-full border border-n300 bg-white px-4 py-2.5 text-[15px] text-n900 outline-none transition focus:border-primary focus:ring-[3px] focus:ring-primary/10"
            />
            <button
              type="submit"
              aria-label="Send message"
              disabled={@assistant_pending}
              class="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary text-white transition hover:bg-primary active:scale-95"
            >
              <svg
                viewBox="0 0 24 24"
                class="h-[18px] w-[18px]"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" />
              </svg>
            </button>
          </.form>
        </div>
      </div>
    </section>
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

  defp endpoint_label(nil), do: "not configured"
  defp endpoint_label(%{url: nil}), do: "not configured"

  defp endpoint_label(%{url: url}) do
    URI.parse(url).host || url
  end

  defp format_error(%Ecto.Changeset{}),
    do: "The chat could not be saved. Please review your setup and try again."

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
