defmodule Sokochat.Meta.ShopRouterTest do
  use Sokochat.DataCase, async: true

  import Sokochat.AccountsFixtures
  import Sokochat.MetaFixtures

  alias Sokochat.Conversations
  alias Sokochat.Meta
  alias Sokochat.Meta.ShopRouter

  setup do
    user = user_fixture()
    shared_line = shared_line_fixture(user)

    royco =
      shop_workspace_fixture(user, shared_line, %{
        name: "Royco Kenya",
        shop_code: "royco"
      })

    brookside =
      shop_workspace_fixture(user, shared_line, %{
        name: "Brookside Kenya",
        shop_code: "brookside"
      })

    %{
      user: user,
      shared_line: shared_line,
      royco: royco,
      brookside: brookside,
      phone: "254700999888"
    }
  end

  test "first shop code binds, strips the token, and dispatches", %{
    shared_line: shared_line,
    brookside: brookside,
    phone: phone
  } do
    assert {:dispatch, shop, "Hi from Brookside", []} =
             ShopRouter.route(
               shared_line,
               phone,
               "Hi from Brookside [shop:brookside]",
               nil
             )

    assert shop.id == brookside.id
    binding = Meta.get_shop_binding(shared_line.id, phone)
    assert binding.workspace_id == brookside.id
  end

  test "later messages without a code stay on the bound shop", %{
    shared_line: shared_line,
    brookside: brookside,
    phone: phone
  } do
    {:ok, _} = Meta.upsert_shop_binding(shared_line.id, phone, brookside.id)

    assert {:dispatch, shop, "Do you sell milk?", []} =
             ShopRouter.route(shared_line, phone, "Do you sell milk?", nil)

    assert shop.id == brookside.id
  end

  test "a new shop code switches shops and leaves prior conversation intact", %{
    shared_line: shared_line,
    royco: royco,
    brookside: brookside,
    phone: phone
  } do
    {:ok, _} = Meta.upsert_shop_binding(shared_line.id, phone, royco.id)
    {:ok, royco_convo} = Conversations.get_or_create_conversation(royco.id, phone, :whatsapp)

    assert {:dispatch, shop, "Hello", opts} =
             ShopRouter.route(shared_line, phone, "[shop:brookside]", nil)

    assert shop.id == brookside.id
    assert opts[:switch_notice] == "You're now with Brookside Kenya."

    binding = Meta.get_shop_binding(shared_line.id, phone)
    assert binding.workspace_id == brookside.id

    assert Conversations.get_conversation(royco.id, phone, :whatsapp).id == royco_convo.id
    refute Conversations.get_conversation(brookside.id, phone, :whatsapp)
  end

  test "unknown code returns a picker and does not bind", %{
    shared_line: shared_line,
    phone: phone
  } do
    assert {:picker, intro, cta} =
             ShopRouter.route(shared_line, phone, "Hello [shop:unknown]", nil)

    assert intro =~ "wasn't recognized"
    assert get_in(cta, ["payload", "items"]) |> length() == 2
    refute Meta.get_shop_binding(shared_line.id, phone)
  end

  test "cold hello without a binding returns a picker", %{
    shared_line: shared_line,
    phone: phone
  } do
    assert {:picker, nil, cta} = ShopRouter.route(shared_line, phone, "Hello", nil)
    ids = cta |> get_in(["payload", "items"]) |> Enum.map(& &1["id"])
    assert "shop:royco" in ids
    assert "shop:brookside" in ids
  end

  test "list reply id binds the chosen shop", %{
    shared_line: shared_line,
    royco: royco,
    phone: phone
  } do
    assert {:dispatch, shop, "Royco Kenya", []} =
             ShopRouter.route(shared_line, phone, "Royco Kenya", "shop:royco")

    assert shop.id == royco.id
  end

  test "two shops never share conversation rows", %{
    royco: royco,
    brookside: brookside,
    phone: phone
  } do
    {:ok, royco_convo} = Conversations.get_or_create_conversation(royco.id, phone, :whatsapp)

    {:ok, brookside_convo} =
      Conversations.get_or_create_conversation(brookside.id, phone, :whatsapp)

    refute royco_convo.id == brookside_convo.id
  end
end
