defmodule Sokochat.MetaFixtures do
  @moduledoc """
  Test helpers for creating `Sokochat.Meta.Connection` and shared-line records.
  """

  alias Sokochat.Meta

  def valid_connection_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "phone_number_id" => "123456789012345",
      "waba_id" => "987654321098765",
      "access_token" => "EAAG-test-access-token"
    })
  end

  def connection_fixture(workspace, attrs \\ %{}) do
    {:ok, connection} =
      Meta.upsert_connection(workspace.id, valid_connection_attributes(attrs))

    connection
  end

  def valid_shared_line_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "phone_number_id" => "555666777888999",
      "waba_id" => "111222333444555",
      "access_token" => "EAAG-shared-line-token",
      "display_phone" => "254700111222"
    })
  end

  def shared_line_fixture(user, attrs \\ %{}) do
    {:ok, shared_line} =
      Meta.upsert_shared_line(user.id, valid_shared_line_attributes(attrs))

    shared_line
  end

  def shop_workspace_fixture(user, shared_line, attrs \\ %{}) do
    {shop_code, attrs} = Map.pop(attrs, :shop_code)
    {shop_code_str, attrs} = Map.pop(attrs, "shop_code", shop_code)

    workspace =
      Sokochat.WorkspacesFixtures.workspace_fixture(
        user,
        Map.merge(%{name: "Shop #{System.unique_integer([:positive])}"}, attrs)
      )

    code = shop_code_str || workspace.slug
    {:ok, workspace} = Meta.join_shared_line(workspace, shared_line, code)
    workspace
  end
end
