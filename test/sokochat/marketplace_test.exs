defmodule Sokochat.MarketplaceTest do
  use Sokochat.DataCase, async: true
  import Sokochat.AccountsFixtures
  import Sokochat.MetaFixtures
  import Sokochat.CatalogsFixtures
  import Sokochat.WorkspacesFixtures
  alias Sokochat.{Marketplace, Meta, Repo}
  alias Sokochat.Marketplace.Orders

  setup do
    owner = user_fixture()
    line = shared_line_fixture(owner)
    {:ok, marketplace} = Marketplace.ensure_workspace(line)
    a = shop_workspace_fixture(user_fixture(), line, %{name: "Shoes", shop_code: "shoes"})
    b = shop_workspace_fixture(user_fixture(), line, %{name: "Phones", shop_code: "phones"})

    shoe =
      item_fixture(catalog_fixture(a), %{title: "Red shoes", metadata: %{"category" => "Shoes"}})

    phone =
      item_fixture(catalog_fixture(b), %{
        title: "Phone case",
        metadata: %{"category" => "Accessories"}
      })

    outsider =
      item_fixture(catalog_fixture(workspace_fixture(user_fixture())), %{title: "Private product"})

    %{
      marketplace: marketplace,
      line: line,
      a: a,
      b: b,
      shoe: shoe,
      phone: phone,
      outsider: outsider
    }
  end

  test "public discovery crosses enrolled merchants but excludes outsiders and archived products",
       ctx do
    assert Marketplace.categories(ctx.marketplace) == ["Accessories", "Shoes"]
    assert Marketplace.get_product(ctx.marketplace, ctx.outsider.id) == nil
    assert Marketplace.get_product(ctx.a, ctx.phone.id) == nil

    assert %{items: [%{"seller_id" => seller}]} =
             Marketplace.search(ctx.marketplace, "Phone", nil, 0)

    assert seller == ctx.b.id
    ctx.phone |> Ecto.Changeset.change(status: "archived") |> Repo.update!()
    assert Marketplace.get_product(ctx.marketplace, ctx.phone.id) == nil
  end

  test "drafts stay private, confirmations bind buyer and line, and replay creates one request",
       ctx do
    assert {:ok, draft} = Orders.draft(ctx.marketplace, "254700111222", ctx.shoe.id, "wamid-one")
    assert Orders.list(ctx.a.id) == []
    assert {:ok, replay} = Orders.draft(ctx.marketplace, "254700111222", ctx.shoe.id, "wamid-one")
    assert replay.id == draft.id
    assert {:error, :unavailable} = Orders.confirm(ctx.marketplace, "254700999999", draft.id)
    assert {:ok, confirmed} = Orders.confirm(ctx.marketplace, "254700111222", draft.id)
    assert confirmed.status == "requested"
    assert {:ok, same} = Orders.confirm(ctx.marketplace, "254700111222", draft.id)
    assert same.id == draft.id
    assert length(Orders.list(ctx.a.id)) == 1
    assert Orders.list(ctx.b.id) == []
    assert {:error, :not_found} = Orders.mark_contacted(ctx.b.id, draft.id)
    assert :ok = Orders.mark_contacted(ctx.a.id, draft.id)
  end

  test "leaving the line or changing a product invalidates pending confirmation", ctx do
    {:ok, draft} = Orders.draft(ctx.marketplace, "254700111222", ctx.shoe.id, "wamid-two")
    ctx.shoe |> Ecto.Changeset.change(price: 99.0) |> Repo.update!()
    assert {:error, :changed} = Orders.confirm(ctx.marketplace, "254700111222", draft.id)
    {:ok, _} = Meta.leave_shared_line(ctx.a)
    assert {:error, :unavailable} = Orders.confirm(ctx.marketplace, "254700111222", draft.id)
  end

  test "model action IDs cannot create a confirmation button", ctx do
    cta = %{
      "type" => "reply_buttons",
      "payload" => %{"buttons" => [%{"id" => "confirm:12", "title" => "Confirm request"}]}
    }

    assert Marketplace.safe_cta(ctx.marketplace, cta) == nil
    assert Marketplace.Chat.preview_reply(ctx.marketplace, "request:#{ctx.shoe.id}").cta == nil
    assert Orders.list(ctx.a.id) == []
  end

  test "fixed welcomes are persisted and wait in the same conversation queue", ctx do
    alias Sokochat.Conversations.{AiTurn, DurableTurns}
    prepared = %{workspace: ctx.marketplace, endpoint: nil}
    reply = Marketplace.welcome(ctx.marketplace)

    assert {:ok, first} =
             DurableTurns.dispatch(prepared, "preview_buyer", "hi", :playground, "server welcome",
               wait: false,
               marketplace_reply: reply,
               source_key: "welcome-one"
             )

    assert {:ok, second} =
             DurableTurns.dispatch(
               prepared,
               "preview_buyer",
               "hello",
               :playground,
               "server welcome", wait: false, marketplace_reply: reply, source_key: "welcome-two")

    assert Repo.get!(AiTurn, first.id).fixed_reply["reply"] == reply.reply
    assert DurableTurns.earlier_pending?(second)

    assert {:ok, duplicate} =
             DurableTurns.dispatch(prepared, "preview_buyer", "hi", :playground, "server welcome",
               wait: false,
               marketplace_reply: reply,
               source_key: "welcome-one"
             )

    assert duplicate.id == first.id
  end
end

defmodule Sokochat.MarketplaceEnrollmentTest do
  use Sokochat.DataCase, async: false
  import Sokochat.AccountsFixtures
  import Sokochat.MetaFixtures
  alias Sokochat.Workspaces

  test "new shops from other accounts join the platform and cannot set the internal marketplace flag" do
    owner = user_fixture()
    line = shared_line_fixture(owner)
    previous = Application.get_env(:sokochat, :marketplace_shared_line_id)
    Application.put_env(:sokochat, :marketplace_shared_line_id, line.id)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:sokochat, :marketplace_shared_line_id, previous),
        else: Application.delete_env(:sokochat, :marketplace_shared_line_id)
    end)

    seller = user_fixture()

    assert {:ok, shop} =
             Workspaces.create_workspace(
               %{name: String.duplicate("Long shop ", 10), language: "en", marketplace: true},
               seller.id
             )

    assert shop.shared_line_id == line.id
    refute shop.marketplace
    assert String.length(shop.shop_code) <= 64
    assert shop.account_id == seller.id
  end
end
