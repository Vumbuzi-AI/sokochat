defmodule SokochatWeb.ProductsLiveTest do
  use SokochatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sokochat.AccountsFixtures
  import Sokochat.WorkspacesFixtures

  alias Sokochat.Catalogs

  @png <<
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82
  >>

  test "a product needs a cover and is saved in KES with optional extras omitted", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/products")

    assert html =~ "Playground"
    assert html =~ "Analytics"
    assert html =~ "Add product"

    assert html =~ "Categories"
    refute html =~ "Buyer-facing product category"

    view
    |> form("#shop-categories", category: %{query: "Fruit"})
    |> render_submit()

    assert render(view) =~ "Fruit"

    view |> element("button", "Add product") |> render_click()
    refute render(view) =~ "Buyer-facing product category"

    assert has_element?(view, "form button[disabled]", "Add product")

    html =
      view
      |> form("form[phx-submit=\"save_item\"]", item: product_params())
      |> render_change()

    assert html =~ "Cover image"

    html =
      view
      |> form("form[phx-submit=\"save_item\"]", item: product_params())
      |> render_submit()

    assert html =~ "Add a cover image."

    upload =
      file_input(view, "form[phx-submit=\"save_item\"]", :cover, [
        %{name: "cover.png", content: @png, type: "image/png"}
      ])

    render_upload(upload, "cover.png")

    html =
      view
      |> form("form[phx-submit=\"save_item\"]", item: product_params())
      |> render_submit()

    assert html =~ "Product saved."
    assert html =~ "Mango"
    assert html =~ "KES 120"

    catalog = Catalogs.get_catalog(workspace.id)
    item = Enum.find(catalog.items, &(&1.title == "Mango"))

    assert item.currency == "KES"
    assert item.price == 120.0
    assert item.image_url =~ "/uploads/catalogs/#{catalog.id}/"
    assert item.metadata["category"] == "Fruit"
    assert item.metadata["variants"] == [%{"label" => "1kg", "price" => 120.0}]
    assert item.metadata["images"] == []
  end

  defp product_params do
    %{
      "title" => "Mango",
      "description" => "Ripe",
      "category" => "Fruit",
      "variants" => %{"0" => %{"label" => "1kg", "price" => "120"}}
    }
  end
end
