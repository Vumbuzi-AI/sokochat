defmodule SokochatWeb.DeskNotices do
  @moduledoc """
  Keeps inbox counts on the desk LiveViews.

  Subscribes to each of the user's shop order topics and refreshes
  `:inbox_counts` when a request is confirmed or marked contacted.
  """

  import Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias Sokochat.Marketplace.Orders
  alias Sokochat.Workspaces

  @desk_views [
    SokochatWeb.WorkspacesLive.Setup,
    SokochatWeb.WorkspacesLive.Inbox,
    SokochatWeb.WorkspacesLive.Analytics,
    SokochatWeb.PlaygroundLive
  ]

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> attach_hook(:desk_notices_params, :handle_params, &refresh/3)
      |> attach_hook(:desk_notices_info, :handle_info, &on_info/2)

    {:cont, socket}
  end

  defp refresh(_params, _uri, socket) do
    {:cont, load(socket)}
  end

  defp on_info(:orders_changed, %Socket{view: SokochatWeb.WorkspacesLive.Inbox} = socket) do
    {:cont, load(socket)}
  end

  defp on_info(:orders_changed, socket) do
    if desk?(socket), do: {:halt, load(socket)}, else: {:cont, socket}
  end

  defp on_info(_message, socket), do: {:cont, socket}

  defp load(socket) do
    if desk?(socket) && socket.assigns[:current_user] do
      ids = workspace_ids(socket)

      socket =
        if connected?(socket) and socket.assigns[:desk_notice_ids] != ids do
          Enum.each(socket.assigns[:desk_notice_ids] || [], fn id ->
            Phoenix.PubSub.unsubscribe(Sokochat.PubSub, Orders.topic(id))
          end)

          Enum.each(ids, &Phoenix.PubSub.subscribe(Sokochat.PubSub, Orders.topic(&1)))
          Phoenix.Component.assign(socket, :desk_notice_ids, ids)
        else
          socket
        end

      Phoenix.Component.assign(socket, :inbox_counts, Orders.pending_counts(ids))
    else
      socket
    end
  end

  defp workspace_ids(socket) do
    socket.assigns.current_user.id
    |> Workspaces.list_workspaces()
    |> Enum.map(& &1.id)
  end

  defp desk?(%Socket{view: view}), do: view in @desk_views
end
