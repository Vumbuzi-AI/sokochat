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
  end
end
