defmodule SokochatWeb.WorkspacesLive.Index do
  use SokochatWeb, :live_view

  alias SokochatWeb.UserAuth

  @impl true
  def mount(_params, _session, socket) do
    path =
      UserAuth.workspace_home_path(
        socket.assigns.current_user,
        socket.assigns[:last_workspace_id]
      )

    {:ok, push_navigate(socket, to: path)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="sr-only">Opening workspace…</div>
    """
  end
end
