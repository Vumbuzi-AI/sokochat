defmodule Whatsappbot.Conversations.DispatcherTest do
  use Whatsappbot.DataCase, async: true

  import Whatsappbot.AccountsFixtures
  import Whatsappbot.EndpointsFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Conversations
  alias Whatsappbot.Conversations.Dispatcher

  setup {Req.Test, :verify_on_exit!}

  setup do
    on_exit(fn ->
      Process.delete(:endpoint_req_options)
      Process.delete(:openai_req_options)
    end)

    :ok
  end

  test "dispatch/4 saves both messages and broadcasts the assistant reply" do
    workspace = workspace_fixture(user_fixture())

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    Req.Test.expect(__MODULE__.EndpointStub, fn conn ->
      assert conn.method == "GET"
      Req.Test.json(conn, [%{"name" => "Tomatoes", "price" => 120}])
    end)

    Req.Test.expect(__MODULE__.OpenAIStub, fn conn ->
      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert request["input"] == [%{"role" => "user", "content" => "Do you have tomatoes?"}]
      assert request["instructions"] =~ "Tomatoes"

      Req.Test.json(conn, %{
        "output" => [
          %{
            "type" => "message",
            "role" => "assistant",
            "content" => [
              %{
                "type" => "output_text",
                "text" =>
                  ~s({"reply":"Yes, tomatoes are available.","cta":{"type":"website","payload":{"url":"https://shop.example.com/tomatoes"}}})
              }
            ]
          }
        ],
        "usage" => %{"input_tokens" => 33, "output_tokens" => 12, "total_tokens" => 45}
      })
    end)

    Process.put(:endpoint_req_options, plug: {Req.Test, __MODULE__.EndpointStub})
    Process.put(:openai_req_options, plug: {Req.Test, __MODULE__.OpenAIStub})

    assert {:ok, conversation} =
             Conversations.get_or_create_conversation(
               workspace.id,
               "playground_#{workspace.id}",
               :playground
             )

    assert :ok = Conversations.subscribe_conversation(conversation.id)

    assert {:ok, assistant_message} =
             Dispatcher.dispatch(
               workspace.id,
               "playground_#{workspace.id}",
               "Do you have tomatoes?",
               :playground
             )

    assert assistant_message.role == "assistant"
    assert assistant_message.tokens_used == 45
    assert assistant_message.cta["type"] == "website"

    assert_receive {:new_message, broadcast_message}
    assert broadcast_message.id == assistant_message.id

    messages = Conversations.list_messages(conversation.id)
    assert Enum.map(messages, & &1.role) == ["user", "assistant"]

    assert hd(messages).endpoint_snapshot == %{
             "items" => [%{"name" => "Tomatoes", "price" => 120}]
           }

    assert List.last(messages).content == "Yes, tomatoes are available."
  end

  test "dispatch/4 uses cached endpoint data when the endpoint is not on-demand" do
    workspace = workspace_fixture(user_fixture())

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      refresh_strategy: "poll_60s",
      cached_data: %{"items" => [%{"name" => "Onions"}]}
    })

    Req.Test.expect(__MODULE__.CachedOpenAIStub, fn conn ->
      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert request["instructions"] =~ "Onions"

      Req.Test.json(conn, %{
        "output" => [
          %{
            "type" => "message",
            "role" => "assistant",
            "content" => [
              %{
                "type" => "output_text",
                "text" => ~s({"reply":"Onions are in stock.","cta":null})
              }
            ]
          }
        ]
      })
    end)

    Process.put(:openai_req_options, plug: {Req.Test, __MODULE__.CachedOpenAIStub})

    assert {:ok, _assistant_message} =
             Dispatcher.dispatch(
               workspace.id,
               "cached-phone",
               "Do you have onions?",
               "playground"
             )

    assert {:ok, conversation} =
             Conversations.get_or_create_conversation(workspace.id, "cached-phone", "playground")

    [user_message, assistant_message] = Conversations.list_messages(conversation.id)

    assert user_message.endpoint_snapshot == %{"items" => [%{"name" => "Onions"}]}
    assert assistant_message.content == "Onions are in stock."
  end

  test "dispatch/4 builds a default website CTA with product preview fields" do
    workspace = workspace_fixture(user_fixture())

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    Req.Test.expect(__MODULE__.PreviewEndpointStub, fn conn ->
      assert conn.method == "GET"

      Req.Test.json(conn, %{
        "products" => [
          %{
            "name" => "Classic Hoodie",
            "price" => 39.99,
            "currency" => "USD",
            "image_url" =>
              "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=900&q=80",
            "url" => "https://shop.example.com/products/classic-hoodie"
          }
        ]
      })
    end)

    Req.Test.expect(__MODULE__.PreviewOpenAIStub, fn conn ->
      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert request["instructions"] =~ "you may include a CTA for that product"

      Req.Test.json(conn, %{
        "output" => [
          %{
            "type" => "message",
            "role" => "assistant",
            "content" => [
              %{
                "type" => "output_text",
                "text" => ~s({"reply":"The Classic Hoodie is available in stock.","cta":null})
              }
            ]
          }
        ]
      })
    end)

    Process.put(:endpoint_req_options, plug: {Req.Test, __MODULE__.PreviewEndpointStub})
    Process.put(:openai_req_options, plug: {Req.Test, __MODULE__.PreviewOpenAIStub})

    assert {:ok, assistant_message} =
             Dispatcher.dispatch(
               workspace.id,
               "preview-phone",
               "Show me the hoodie",
               :playground
             )

    assert assistant_message.cta == %{
             "type" => "website",
             "payload" => %{
               "body" => "USD 39.99",
               "image_url" =>
                 "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=900&q=80",
               "title" => "Classic Hoodie",
               "url" => "https://shop.example.com/products/classic-hoodie"
             }
           }
  end
end
