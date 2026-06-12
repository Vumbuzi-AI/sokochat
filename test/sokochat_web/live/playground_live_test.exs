defmodule WhatsappbotWeb.PlaygroundLiveTest do
  use WhatsappbotWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Whatsappbot.AccountsFixtures
  import Whatsappbot.CTARulesFixtures
  import Whatsappbot.EndpointsFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Conversations

  setup {Req.Test, :verify_on_exit!}

  setup do
    on_exit(fn ->
      Process.delete(:endpoint_req_options)
      Process.delete(:openai_req_options)
      Application.delete_env(:whatsappbot, :endpoint_req_options)
      Application.delete_env(:whatsappbot, :openai_req_options)
    end)

    :ok
  end

  test "sending a message shows the assistant reply", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    stub_endpoint(%{"items" => [%{"name" => "Tomatoes", "price" => 120}]})

    stub_openai(~s({"reply":"Tomatoes are available today.","cta":null}))

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/playground")

    view
    |> form("form", playground: %{message: "Do you have tomatoes?"})
    |> render_submit()

    html = render_async(view, 1_000)

    assert html =~ "Do you have tomatoes?"
    assert html =~ "Tomatoes are available today."
  end

  test "sending a message shows optimistic chat state before the assistant reply lands", %{
    conn: conn
  } do
    user = user_fixture()
    workspace = workspace_fixture(user)

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    stub_endpoint(%{"items" => [%{"name" => "Tomatoes", "price" => 120}]})
    stub_openai_blocking(self(), ~s({"reply":"Tomatoes are available today.","cta":null}))

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/playground")

    view
    |> form("form", playground: %{message: "Do you have tomatoes?"})
    |> render_submit()

    assert_receive {:openai_called, openai_waiter}, 1_000

    pending_html = render(view)

    assert pending_html =~ "Do you have tomatoes?"
    assert pending_html =~ "Sending..."
    assert pending_html =~ "Bot is typing..."

    send(openai_waiter, :continue_openai)

    html = render_async(view, 1_000)

    assert html =~ "Tomatoes are available today."
    refute html =~ "Sending..."
    refute html =~ "Bot is typing..."
  end

  test "cta appears in the assistant bubble when the reply includes one", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    cta_rule_fixture(workspace)

    stub_endpoint(%{"items" => [%{"name" => "Tomatoes", "price" => 120}]})

    stub_openai(
      ~s({"reply":"You can order tomatoes now.","cta":{"type":"website","payload":{"url":"https://shop.example.com/checkout"}}})
    )

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/playground")

    view
    |> form("form", playground: %{message: "I want to buy tomatoes"})
    |> render_submit()

    html = render_async(view, 1_000)

    assert html =~ "You can order tomatoes now."
    assert html =~ "Open link"
    assert html =~ "https://shop.example.com/checkout"
  end

  test "assistant bubble shows product image preview fields from CTA payload", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    stub_endpoint(%{
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

    stub_openai(
      ~s({"reply":"The Classic Hoodie is available.","cta":{"type":"website","payload":{"url":"https://shop.example.com/products/classic-hoodie","title":"Classic Hoodie","body":"USD 39.99","image_url":"https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=900&q=80"}}})
    )

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/playground")

    view
    |> form("form", playground: %{message: "Show me the hoodie"})
    |> render_submit()

    html = render_async(view, 1_000)

    assert html =~ "Classic Hoodie"
    assert html =~ "USD 39.99"

    assert html =~ "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab"
  end

  test "clear chat removes the playground messages", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, conversation} =
      Conversations.get_or_create_conversation(
        workspace.id,
        Conversations.playground_phone_number(workspace.id),
        :playground
      )

    {:ok, _user_message} = Conversations.add_message(conversation, :user, "Hello there")

    {:ok, _assistant_message} =
      Conversations.add_message(conversation, :assistant, "Hi, welcome back")

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/playground")

    assert render(view) =~ "Hi, welcome back"

    view
    |> element("button[phx-click=\"clear_chat\"]")
    |> render_click()

    html = render(view)

    refute html =~ "Hi, welcome back"
    refute html =~ "Hello there"
    assert html =~ "Send a message to test your bot"

    assert Conversations.get_conversation(
             workspace.id,
             Conversations.playground_phone_number(workspace.id),
             :playground
           ) == nil
  end

  test "clicking a list message item sends it as a WhatsApp-style selection", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    stub_endpoint(%{"items" => [%{"name" => "Desk Lamp", "price" => 42.10}]})
    stub_openai(~s({"reply":"Home picks include the Desk Lamp.","cta":null}))

    {:ok, conversation} =
      Conversations.get_or_create_conversation(
        workspace.id,
        Conversations.playground_phone_number(workspace.id),
        :playground
      )

    {:ok, _assistant_message} =
      Conversations.add_message(
        conversation,
        :assistant,
        "What are you interested in?",
        cta: %{
          "type" => "list_message",
          "payload" => %{
            "items" => [
              %{"title" => "Electronics", "description" => "Phones, audio, and gadgets"},
              %{"title" => "Home", "description" => "Decor and home essentials"}
            ]
          }
        }
      )

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/playground")

    view
    |> element("button[phx-value-message=\"Home\"]")
    |> render_click()

    html = render_async(view, 1_000)

    assert html =~ "Home"
    assert html =~ "Home picks include the Desk Lamp."
  end

  defp stub_endpoint(payload) do
    Req.Test.expect(__MODULE__.EndpointStub, fn conn ->
      assert conn.method == "GET"
      Req.Test.json(conn, payload)
    end)

    stub_options = [plug: {Req.Test, __MODULE__.EndpointStub}]
    Process.put(:endpoint_req_options, stub_options)
    Application.put_env(:whatsappbot, :endpoint_req_options, stub_options)
  end

  defp stub_openai(response_text) do
    Req.Test.expect(__MODULE__.OpenAIStub, fn conn ->
      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert is_binary(request["instructions"])
      assert request["input"] != []

      Req.Test.json(conn, %{
        "output" => [
          %{
            "type" => "message",
            "role" => "assistant",
            "content" => [%{"type" => "output_text", "text" => response_text}]
          }
        ],
        "usage" => %{"input_tokens" => 21, "output_tokens" => 9, "total_tokens" => 30}
      })
    end)

    stub_options = [plug: {Req.Test, __MODULE__.OpenAIStub}]
    Process.put(:openai_req_options, stub_options)
    Application.put_env(:whatsappbot, :openai_req_options, stub_options)
  end

  defp stub_openai_blocking(test_pid, response_text) do
    Req.Test.expect(__MODULE__.BlockingOpenAIStub, fn conn ->
      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert is_binary(request["instructions"])
      assert request["input"] != []

      send(test_pid, {:openai_called, self()})

      receive do
        :continue_openai -> :ok
      after
        1_000 -> flunk("expected test to resume the blocked OpenAI stub")
      end

      Req.Test.json(conn, %{
        "output" => [
          %{
            "type" => "message",
            "role" => "assistant",
            "content" => [%{"type" => "output_text", "text" => response_text}]
          }
        ],
        "usage" => %{"input_tokens" => 21, "output_tokens" => 9, "total_tokens" => 30}
      })
    end)

    stub_options = [plug: {Req.Test, __MODULE__.BlockingOpenAIStub}]
    Process.put(:openai_req_options, stub_options)
    Application.put_env(:whatsappbot, :openai_req_options, stub_options)
  end
end
