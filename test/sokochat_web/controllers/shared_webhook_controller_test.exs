defmodule SokochatWeb.SharedWebhookControllerTest do
  use SokochatWeb.ConnCase, async: true
  use Oban.Testing, repo: Sokochat.Repo

  import Sokochat.AccountsFixtures
  import Sokochat.MetaFixtures

  alias Sokochat.Meta
  alias Sokochat.Workers.ProcessInboundMessage

  setup do
    user = user_fixture()
    shared_line = shared_line_fixture(user)
    brookside = shop_workspace_fixture(user, shared_line, %{shop_code: "brookside"})

    %{user: user, shared_line: shared_line, brookside: brookside}
  end

  describe "GET shared verification" do
    test "echoes the challenge and marks the shared line verified", %{
      conn: conn,
      shared_line: shared_line
    } do
      conn =
        get(conn, ~p"/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => shared_line.verify_token,
          "hub.challenge" => "shared-challenge"
        })

      assert text_response(conn, 200) == "shared-challenge"

      reloaded = Meta.get_shared_line(shared_line.account_id)
      assert reloaded.status == "active"
      assert reloaded.webhook_verified_at
    end

    test "returns 403 for a wrong verify token", %{conn: conn} do
      conn =
        get(conn, ~p"/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => "wrong",
          "hub.challenge" => "x"
        })

      assert response(conn, 403)
    end
  end

  describe "POST shared inbound" do
    test "enqueues a shared-line job with the reply id", %{
      conn: conn,
      shared_line: shared_line
    } do
      conn =
        post(
          conn,
          ~p"/webhooks/whatsapp",
          list_reply_payload("wamid.SHARED1", "Brookside Kenya", "shop:brookside", shared_line)
        )

      assert response(conn, 200)

      assert_enqueued(
        worker: ProcessInboundMessage,
        args: %{
          "shared_line_id" => shared_line.id,
          "phone_number" => "254700999888",
          "message_text" => "Brookside Kenya",
          "whatsapp_message_id" => "wamid.SHARED1",
          "reply_id" => "shop:brookside"
        }
      )
    end

    test "slug route still enqueues a workspace job without shared routing", %{
      conn: conn,
      user: user
    } do
      workspace = Sokochat.WorkspacesFixtures.workspace_fixture(user)
      connection = connection_fixture(workspace)

      conn =
        post(
          conn,
          ~p"/webhooks/whatsapp/#{workspace.slug}",
          text_payload("wamid.SLUG1", "Hi", connection.phone_number_id)
        )

      assert response(conn, 200)

      assert_enqueued(
        worker: ProcessInboundMessage,
        args: %{
          "workspace_id" => workspace.id,
          "phone_number" => "254700999888",
          "message_text" => "Hi",
          "whatsapp_message_id" => "wamid.SLUG1",
          "reply_id" => nil
        }
      )
    end
  end

  defp text_payload(message_id, text, phone_number_id) do
    %{
      "object" => "whatsapp_business_account",
      "entry" => [
        %{
          "changes" => [
            %{
              "field" => "messages",
              "value" => %{
                "metadata" => %{"phone_number_id" => phone_number_id},
                "messages" => [
                  %{
                    "from" => "254700999888",
                    "id" => message_id,
                    "type" => "text",
                    "text" => %{"body" => text}
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end

  defp list_reply_payload(message_id, title, reply_id, shared_line) do
    %{
      "object" => "whatsapp_business_account",
      "entry" => [
        %{
          "changes" => [
            %{
              "field" => "messages",
              "value" => %{
                "metadata" => %{"phone_number_id" => shared_line.phone_number_id},
                "messages" => [
                  %{
                    "from" => "254700999888",
                    "id" => message_id,
                    "type" => "interactive",
                    "interactive" => %{
                      "type" => "list_reply",
                      "list_reply" => %{"id" => reply_id, "title" => title}
                    }
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end
end
