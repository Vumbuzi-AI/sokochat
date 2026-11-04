defmodule SokochatWeb.SharedLineLiveTest do
  use SokochatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sokochat.AccountsFixtures
  import Sokochat.MetaFixtures
  import Sokochat.WorkspacesFixtures

  alias Sokochat.Meta

  test "saving the shared line reveals the webhook URL", %{conn: conn} do
    user = user_fixture()

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/shared-line")

    assert html =~ "Shared WhatsApp line"
    refute html =~ "Callback URL"

    params = %{
      "phone_number_id" => "555666777888999",
      "waba_id" => "111222333444555",
      "access_token" => "EAAG-shared",
      "display_phone" => "+254700111222"
    }

    html =
      view
      |> form("form", shared_line: params)
      |> render_submit()

    assert html =~ "Shared line saved"
    assert html =~ "Callback URL"
    assert html =~ "/webhooks/whatsapp"
    refute html =~ "/webhooks/whatsapp/"

    shared_line = Meta.get_shared_line(user.id)
    assert shared_line.display_phone == "254700111222"
    assert html =~ shared_line.verify_token
  end

  test "joining a workspace reveals the wa.me link", %{conn: conn} do
    user = user_fixture()
    shared_line = shared_line_fixture(user)
    workspace = workspace_fixture(user, %{name: "Brookside Kenya"})

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/meta")

    assert html =~ "Use the shared line"
    refute html =~ "Buyer link"

    view
    |> element("form[phx-change=update_shop_code]")
    |> render_change(%{"shop_code" => "brookside"})

    html =
      view
      |> element("button", "Join shared line")
      |> render_click()

    assert html =~ "Buyer link"
    assert html =~ "wa.me/#{shared_line.display_phone}"
    assert html =~ "shop%3Abrookside"

    workspace = Meta.get_shop_by_code(shared_line.id, "brookside")
    assert workspace.id
    assert workspace.shop_code == "brookside"
  end
end
