defmodule Sokochat.CatalogsTest do
  use Sokochat.DataCase

  import Sokochat.AccountsFixtures
  import Sokochat.CatalogsFixtures
  import Sokochat.WorkspacesFixtures

  alias Sokochat.Catalogs

  describe "upsert_field/2" do
    test "autogenerates a title-cased label from the key" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      catalog = catalog_fixture(workspace)

      assert {:ok, field} =
               Catalogs.upsert_field(catalog, %{
                 "key" => "size_difference",
                 "field_type" => "text"
               })

      assert field.label == "Size Difference"
    end

    test "rejects the built-in category key" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      catalog = catalog_fixture(workspace)

      assert {:error, changeset} =
               Catalogs.upsert_field(catalog, %{
                 "key" => "category",
                 "field_type" => "text"
               })

      assert %{key: ["is already built in"]} = errors_on(changeset)
    end
  end

  describe "shop categories" do
    test "adds unique names and lists them for the assistant" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      catalog = catalog_fixture(workspace)

      assert {:ok, catalog} = Catalogs.add_category(catalog, "  fruit ")
      assert {:ok, catalog} = Catalogs.add_category(catalog, "Shoes")
      assert Catalogs.shop_categories(catalog) == ["fruit", "Shoes"]

      item_fixture(catalog, %{
        title: "Mango",
        metadata: %{"category" => "Fruit"}
      })

      assert Catalogs.list_item_categories(workspace.id) == ["fruit", "Shoes"]
    end
  end
end
