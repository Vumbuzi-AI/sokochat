defmodule SokochatWeb.WorkspacesLiveTest do
  use SokochatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sokochat.AccountsFixtures
  import Sokochat.CatalogsFixtures
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

    view
    |> element("button[phx-value-tab=\"manual\"]")
    |> render_click()

    assert render(view) =~ "Set up your catalog model"
  end

  test "business profile step saves company context", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}")

    assert html =~ "Business Profile"

    view
    |> form("form[phx-submit=\"save_business\"]",
      workspace: %{
        company_name: "Acme Ltd",
        industry: "Electronics",
        location: "Nairobi",
        phone_number: "+254700000000",
        about: "We sell gadgets."
      }
    )
    |> render_submit()

    assert render(view) =~ "Business profile saved."

    updated = Sokochat.Workspaces.get_workspace!(workspace.id, user.id)
    assert updated.company_name == "Acme Ltd"
    assert updated.industry == "Electronics"
    assert updated.phone_number == "+254700000000"
  end

  test "field modal only asks for the key", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)
    _catalog = catalog_fixture(workspace)

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/endpoint")

    view
    |> element("button[phx-value-tab=\"manual\"]")
    |> render_click()

    assert render_click(element(view, "button[phx-click=\"new_field\"]")) =~ "Add field"

    html = render(view)

    assert html =~ "Field key"
    refute html =~ ~s(name="field[label]")
  end
end
