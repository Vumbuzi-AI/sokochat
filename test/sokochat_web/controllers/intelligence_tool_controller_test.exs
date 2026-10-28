defmodule SokochatWeb.IntelligenceToolControllerTest do
  use SokochatWeb.ConnCase, async: false
  import Sokochat.AccountsFixtures
  import Sokochat.WorkspacesFixtures
  alias Sokochat.{Catalogs, Conversations}

  setup do
    old = Application.get_env(:sokochat, :intelligence, [])
    token = String.duplicate("p", 32)
    Application.put_env(:sokochat, :intelligence, Keyword.put(old, :pi_token, token))
    on_exit(fn -> Application.put_env(:sokochat, :intelligence, old) end)
    shop = workspace_fixture(user_fixture(), %{name: "Shoes"})
    other = workspace_fixture(user_fixture(), %{name: "Private shop"})

    {:ok, conversation} =
      Conversations.get_or_create_conversation(shop.id, "demo-phone", :playground)

    {:ok, message} = Conversations.add_message(conversation, :user, "Show shoes")

    Sokochat.Repo.insert!(%Sokochat.Conversations.AiTurn{
      workspace_id: shop.id,
      conversation_id: conversation.id,
      user_message_id: message.id,
      instructions: "Shop context"
    })

    {:ok, catalog} = Catalogs.upsert_catalog(other.id, %{name: "Private inventory"})

    {:ok, item} =
      Catalogs.upsert_item(catalog, %{title: "Private product", external_id: "private-sku"})

    {:ok, own_catalog} = Catalogs.upsert_catalog(shop.id, %{name: "Shoe inventory"})

    {:ok, own_item} =
      Catalogs.upsert_item(own_catalog, %{
        title: "Adidas Spezial",
        external_id: "adidas-spezial",
        image_url: "https://example.com/adidas.webp",
        price: 6500,
        currency: "KES"
      })

    %{
      token: token,
      shop: shop,
      other: other,
      conversation: conversation,
      message: message,
      private_item: item,
      own_item: own_item
    }
  end

  test "rejects unauthenticated tool calls", %{conn: conn, shop: shop, conversation: conversation} do
    conn =
      get(
        conn,
        "/api/intelligence/workspaces/#{shop.id}/conversations/#{conversation.id}/tools/shop_profile"
      )

    assert json_response(conn, 401)["error"] == "Unauthorized tool scope"
  end

  test "a valid conversation cannot be rebound to another tenant", ctx do
    conn =
      ctx.conn
      |> put_req_header("authorization", "Bearer " <> ctx.token)
      |> put_req_header("x-pi-request-id", "message-#{ctx.message.id}")
      |> get(
        "/api/intelligence/workspaces/#{ctx.other.id}/conversations/#{ctx.conversation.id}/tools/shop_profile"
      )

    assert json_response(conn, 401)["error"] == "Unauthorized tool scope"
  end

  test "product lookup never returns a different workspace's inventory", ctx do
    conn =
      ctx.conn
      |> put_req_header("authorization", "Bearer " <> ctx.token)
      |> put_req_header("x-pi-request-id", "message-#{ctx.message.id}")
      |> get(
        "/api/intelligence/workspaces/#{ctx.shop.id}/conversations/#{ctx.conversation.id}/tools/get_product",
        %{product_id: ctx.private_item.external_id}
      )

    assert json_response(conn, 404)["error"] == "Product not found"
  end

  test "an admitted turn can retrieve its own product facts and image", ctx do
    conn =
      ctx.conn
      |> put_req_header("authorization", "Bearer " <> ctx.token)
      |> put_req_header("x-pi-request-id", "message-#{ctx.message.id}")
      |> get(
        "/api/intelligence/workspaces/#{ctx.shop.id}/conversations/#{ctx.conversation.id}/tools/get_product",
        %{product_id: ctx.own_item.external_id}
      )

    assert %{
             "item" => %{
               "title" => "Adidas Spezial",
               "price" => 6500.0,
               "image_url" => "https://example.com/adidas.webp"
             }
           } = json_response(conn, 200)
  end

  test "a settled turn cannot continue reading inventory", ctx do
    import Ecto.Query

    from(t in Sokochat.Conversations.AiTurn, where: t.user_message_id == ^ctx.message.id)
    |> Sokochat.Repo.update_all(set: [status: "failed"])

    conn =
      ctx.conn
      |> put_req_header("authorization", "Bearer " <> ctx.token)
      |> put_req_header("x-pi-request-id", "message-#{ctx.message.id}")
      |> get(
        "/api/intelligence/workspaces/#{ctx.shop.id}/conversations/#{ctx.conversation.id}/tools/get_product",
        %{product_id: ctx.own_item.external_id}
      )

    assert json_response(conn, 401)["error"] == "Unauthorized tool scope"
  end
end
