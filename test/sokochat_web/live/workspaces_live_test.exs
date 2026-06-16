defmodule SokochatWeb.WorkspacesLiveTest do
  use SokochatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sokochat.AccountsFixtures
  import Sokochat.WorkspacesFixtures

  test "another user's workspace cannot be accessed", %{conn: conn} do
    owner = user_fixture()
    intruder = user_fixture()
    workspace = workspace_fixture(owner)

    assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
             conn
             |> log_in_user(intruder)
             |> live(~p"/workspaces/#{workspace.id}")

    assert to == ~p"/workspaces"
    assert flash["error"] == "Workspace not found."
  end

  test "endpoint page renders for a workspace without a catalog", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/endpoint")

    assert html =~ "Data Ingestion"
    assert render(view) =~ "Manual catalog model"
  end
end
