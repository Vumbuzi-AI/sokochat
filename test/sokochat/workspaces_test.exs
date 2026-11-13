defmodule Sokochat.WorkspacesTest do
  use Sokochat.DataCase

  alias Sokochat.Workspaces

  import Sokochat.AccountsFixtures
  import Sokochat.WorkspacesFixtures

  describe "create_workspace/2" do
    test "defaults to English and Swahili when the new-shop form omits language" do
      user = user_fixture()

      assert {:ok, workspace} =
               Workspaces.create_workspace(%{"name" => "New shop", "website_url" => ""}, user.id)

      assert workspace.language == "both"
    end

    test "still rejects an explicitly invalid language" do
      user = user_fixture()

      assert {:error, changeset} =
               Workspaces.create_workspace(%{name: "New shop", language: "invalid"}, user.id)

      assert errors_on(changeset).language == ["is invalid"]
    end

    test "auto-generates a slug from the workspace name" do
      user = user_fixture()

      assert {:ok, workspace} =
               Workspaces.create_workspace(
                 valid_workspace_attributes(name: "Fresh Farm Produce"),
                 user.id
               )

      assert workspace.slug == "fresh-farm-produce"
    end
  end

  describe "get_workspace!/2" do
    test "raises when another user tries to access the workspace" do
      owner = user_fixture()
      intruder = user_fixture()
      workspace = workspace_fixture(owner)

      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(workspace.id, intruder.id)
      end
    end
  end

  describe "update_workspace/2" do
    test "updates AI instructions" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, updated_workspace} =
               Workspaces.update_workspace(workspace, %{
                 "ai_instructions" => "Only answer using the latest product data."
               })

      assert updated_workspace.ai_instructions == "Only answer using the latest product data."
    end
  end

  test "removing the last delivery area persists and collection requires an address" do
    workspace = workspace_fixture(user_fixture())
    assert {:error, changeset} = Workspaces.update_workspace(workspace, %{pickup_enabled: true})
    assert errors_on(changeset).location == ["can't be blank"]

    assert {:ok, workspace} =
             Workspaces.update_workspace(workspace, %{
               delivery_enabled: true,
               delivery_rates: [%{area: "CBD", fee: "0"}]
             })

    assert length(workspace.delivery_rates) == 1
    assert {:ok, workspace} = Workspaces.update_workspace(workspace, %{"delivery_rates" => ""})
    assert workspace.delivery_rates == []

    assert {:error, changeset} =
             Workspaces.update_workspace(workspace, %{delivery_quote_outside: false})

    assert errors_on(changeset).delivery_rates == ["add an area or accept delivery quotes"]
  end
end
