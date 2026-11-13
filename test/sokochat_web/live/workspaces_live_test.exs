defmodule SokochatWeb.WorkspacesLiveTest do
  use SokochatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sokochat.AccountsFixtures
  import Sokochat.CatalogsFixtures
  import Sokochat.EndpointsFixtures
  import Sokochat.MetaFixtures
  import Sokochat.WorkspacesFixtures

  setup {Req.Test, :verify_on_exit!}

  setup do
    on_exit(fn ->
      Application.delete_env(:sokochat, :endpoint_req_options)
      Application.delete_env(:sokochat, :website_req_options)
    end)

    :ok
  end

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

  test "regenerate ai context refreshes the preview from the live JSON feed", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, workspace} =
      Sokochat.Workspaces.update_workspace(workspace, %{"data_source" => "api"})

    _endpoint =
      endpoint_fixture(workspace, %{
        url: "https://catalog.test/products",
        refresh_strategy: "on_demand",
        cached_data: %{"items" => [%{"name" => "Old item"}]}
      })

    Req.Test.expect(__MODULE__.RefreshStub, fn conn ->
      assert conn.method == "GET"

      Req.Test.json(conn, %{"items" => [%{"name" => "New item"}]})
    end)

    Application.put_env(:sokochat, :endpoint_req_options,
      plug: {Req.Test, __MODULE__.RefreshStub}
    )

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/endpoint")

    view
    |> element("button[phx-value-tab=\"preview\"]")
    |> render_click()

    assert render(view) =~ "Regenerate AI context"

    refreshed_html =
      view
      |> element("button[phx-click=\"regenerate_ai_context\"]")
      |> render_click()

    assert refreshed_html =~ "AI context regenerated from the live JSON feed."
  end

  test "business profile step saves company context", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}")

    assert html =~ "Business profile"
    assert has_element?(view, "button[disabled]", "Save changes")

    params = %{
      company_name: "Acme Ltd",
      industry: "Electronics",
      location: "Nairobi",
      phone_number: "+254700000000",
      about: "We sell gadgets."
    }

    view
    |> form("form[phx-submit=\"save_business\"]", workspace: params)
    |> render_change()

    refute has_element?(view, "button[disabled]", "Save changes")

    view
    |> form("form[phx-submit=\"save_business\"]", workspace: params)
    |> render_submit()

    assert render(view) =~ "Business profile saved."
    assert has_element?(view, "button[disabled]", "Save changes")

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

  test "new workspace submits without a language field and recovers after validation", %{
    conn: conn
  } do
    user = user_fixture()
    {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/workspaces/new")

    html = view |> form("form", workspace: %{name: "X", website_url: ""}) |> render_submit()
    assert html =~ "Unable to save workspace"
    assert html =~ "Name should be at least 2 character"
    assert Sokochat.Workspaces.get_home_workspace(user.id) == nil

    view |> form("form", workspace: %{name: "New shop", website_url: ""}) |> render_submit()
    workspace = Sokochat.Workspaces.get_home_workspace(user.id)
    assert workspace.name == "New shop"
    assert workspace.language == "both"
    assert_redirect(view, ~p"/workspaces/#{workspace.id}")
  end

  test "a new workspace reads the website into AI content", %{conn: conn} do
    user = user_fixture()

    Req.Test.expect(SiteStub, fn conn ->
      Req.Test.html(conn, """
      <html>
        <head>
          <title>Soko Shoes</title>
          <meta name="description" content="Nairobi sneaker shop.">
        </head>
        <body><p>EU sizes, same-day delivery.</p></body>
      </html>
      """)
    end)

    Application.put_env(:sokochat, :website_req_options, plug: {Req.Test, SiteStub})

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/new")

    Req.Test.allow(SiteStub, self(), view.pid)

    assert html =~ "Website"
    assert html =~ "Logo"
    refute html =~ "AI instructions"

    view
    |> form("form", workspace: %{name: "Soko Shoes", website_url: "https://example.com"})
    |> render_submit()

    workspace = Sokochat.Workspaces.get_home_workspace(user.id)
    assert workspace.name == "Soko Shoes"
    assert workspace.website_url == "https://example.com"
    assert workspace.ai_instructions =~ "Business: Soko Shoes"
    assert workspace.ai_instructions =~ "Nairobi sneaker shop."

    {:ok, _shop, shop_html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}")

    assert shop_html =~ "AI content"
    assert shop_html =~ "Business: Soko Shoes"
  end

  test "cancel on a new workspace leaves the form", %{conn: conn} do
    user = user_fixture()
    home = workspace_fixture(user)

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/new")

    assert {:error, {:live_redirect, %{to: to}}} =
             view |> element("button", "Cancel") |> render_click()

    assert to == ~p"/workspaces/#{home.id}"
  end

  test "cancel with no shop opens account settings", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/new")

    assert {:error, {:live_redirect, %{to: to}}} =
             view |> element("button", "Cancel") |> render_click()

    assert to == ~p"/users/settings"
  end

  test "inbox and the shop switcher show requests that still need a reply", %{conn: conn} do
    user = user_fixture()
    line = shared_line_fixture(user)
    here = shop_workspace_fixture(user, line, %{name: "Soko Shoes"})
    there = shop_workspace_fixture(user, line, %{name: "Soko Bags"})

    order_request!(here, line, "here-1")
    order_request!(there, line, "there-1")

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{here.id}/inbox")

    assert has_element?(view, "a[data-id='inbox'] .soko-nav-count", "1")
    assert has_element?(view, "#workspace-switcher-dock > summary .soko-nav-count", "1")
    assert has_element?(view, "#workspace-switcher-dock a", "Soko Bags")

    order_request!(there, line, "there-2")

    Phoenix.PubSub.broadcast(
      Sokochat.PubSub,
      Sokochat.Marketplace.Orders.topic(there.id),
      :orders_changed
    )

    _ = :sys.get_state(view.pid)

    assert has_element?(view, "#workspace-switcher-dock > summary .soko-nav-count", "2")
    assert has_element?(view, "a[data-id='inbox'] .soko-nav-count", "1")
  end

  defp order_request!(workspace, line, key) do
    Sokochat.Repo.insert!(%Sokochat.Marketplace.OrderRequest{
      workspace_id: workspace.id,
      shared_line_id: line.id,
      phone_number: "254700000001",
      source_key: key,
      product: %{"title" => "Nike Shox"},
      status: "requested",
      requested_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  test "workspaces index opens the home workspace", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    assert {:error, {:live_redirect, %{to: to}}} =
             conn
             |> log_in_user(user)
             |> live(~p"/workspaces")

    assert to == ~p"/workspaces/#{workspace.id}"
  end
end
