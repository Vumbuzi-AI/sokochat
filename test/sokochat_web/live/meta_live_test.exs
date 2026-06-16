defmodule SokochatWeb.MetaLiveTest do
  use SokochatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sokochat.AccountsFixtures
  import Sokochat.CTARulesFixtures
  import Sokochat.EndpointsFixtures
  import Sokochat.MetaFixtures
  import Sokochat.WorkspacesFixtures

  alias Sokochat.Meta

  test "shows setup alerts before credentials are saved", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, _view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/meta")

    assert html =~ "Start in Meta"
    assert html =~ "Phone Number ID"
    assert html =~ "Finish the workspace before going live"
    assert html =~ "Data Ingestion and CTA Rules"
  end

  test "saving credentials creates a connection and reveals the webhook panel", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/meta")

    assert html =~ "Meta Connection"
    refute html =~ "Callback URL"

    params = %{
      "phone_number_id" => "123456789012345",
      "waba_id" => "987654321098765",
      "access_token" => "EAAG-secret"
    }

    html =
      view
      |> form("form", connection: params)
      |> render_submit()

    assert html =~ "Meta credentials saved"
    assert html =~ "Callback URL"
    assert html =~ "/webhooks/whatsapp/#{workspace.slug}"
    assert html =~ "Webhook still needs verification"

    connection = Meta.get_connection(workspace.id)
    assert connection.phone_number_id == "123456789012345"
    assert connection.access_token == "EAAG-secret"
    assert html =~ connection.verify_token
  end

  test "workspace setup shows Meta validated when the connection is active", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)
    endpoint_fixture(workspace)
    cta_rule_fixture(workspace)
    connection = connection_fixture(workspace)
    {:ok, _} = Meta.mark_verified(connection)

    {:ok, _view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}?step=meta")

    assert html =~ "Meta Verification Pipeline"
    assert html =~ "Pre-Live Stage Validated"
  end

  test "redirects when the workspace belongs to someone else", %{conn: conn} do
    other_workspace = workspace_fixture(user_fixture())

    assert {:error, {:live_redirect, %{to: "/workspaces"}}} =
             conn
             |> log_in_user(user_fixture())
             |> live(~p"/workspaces/#{other_workspace.id}/meta")
  end
end
