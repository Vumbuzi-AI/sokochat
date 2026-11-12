defmodule Sokochat.Meta.SharedLineTest do
  use Sokochat.DataCase, async: true

  import Sokochat.AccountsFixtures
  import Sokochat.MetaFixtures
  import Sokochat.WorkspacesFixtures

  alias Sokochat.Meta

  test "upserts a shared line and preserves the verify token" do
    user = user_fixture()

    {:ok, first} =
      Meta.upsert_shared_line(user.id, valid_shared_line_attributes())

    assert first.display_phone == "254700111222"
    assert first.verify_token

    {:ok, second} =
      Meta.upsert_shared_line(user.id, valid_shared_line_attributes(%{"waba_id" => "changed"}))

    assert second.id == first.id
    assert second.verify_token == first.verify_token
    assert second.waba_id == "changed"
    assert second.status == "pending"
  end

  test "join and leave shared line sets shop_code" do
    user = user_fixture()
    shared_line = shared_line_fixture(user)
    workspace = workspace_fixture(user, %{name: "Brookside Kenya"})

    {:ok, joined} = Meta.join_shared_line(workspace, shared_line, "brookside")
    assert joined.shared_line_id == shared_line.id
    assert joined.shop_code == "brookside"

    url = Meta.shop_wa_me_url(shared_line, joined)
    assert url =~ "https://wa.me/254700111222?text="
    assert url =~ "shop%3Abrookside" or url =~ URI.encode_www_form("[shop:brookside]")
    assert url =~ URI.encode_www_form("What do you have at Brookside Kenya?")

    {:ok, left} = Meta.leave_shared_line(joined)
    assert is_nil(left.shared_line_id)
    assert is_nil(left.shop_code)
  end

  test "connection_for_send prefers the shared line" do
    user = user_fixture()
    shared_line = shared_line_fixture(user)
    shop = shop_workspace_fixture(user, shared_line, %{shop_code: "royco"})
    _dedicated = connection_fixture(shop)

    sendable = Meta.connection_for_send(shop.id)
    assert sendable.id == shared_line.id
    assert sendable.phone_number_id == shared_line.phone_number_id
  end

  test "connection_for_send falls back to the dedicated connection" do
    user = user_fixture()
    workspace = workspace_fixture(user)
    connection = connection_fixture(workspace)

    sendable = Meta.connection_for_send(workspace.id)
    assert sendable.id == connection.id
    assert sendable.phone_number_id == connection.phone_number_id
  end
end
