defmodule Sokochat.AI.OpenAIClientTest do
  use ExUnit.Case, async: true

  alias Sokochat.AI.OpenAIClient

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous_config = Application.fetch_env!(:sokochat, :openai)

    Application.put_env(
      :sokochat,
      :openai,
      previous_config
      |> Keyword.put(:api_key, "test-openai-key")
      |> Keyword.put(:model, "gpt-5.5")
    )

    on_exit(fn ->
      Process.delete(:openai_req_options)
      Application.put_env(:sokochat, :openai, previous_config)
    end)

    :ok
  end

  test "chat/2 sends a Responses API request and parses structured JSON replies" do
    Req.Test.expect(__MODULE__.JsonReplyStub, fn conn ->
      assert conn.method == "POST"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-openai-key"]

      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert request["instructions"] == "System prompt"
      assert request["input"] == [%{"role" => "user", "content" => "Do you have tomatoes?"}]
      assert request["reasoning"] == %{"effort" => "low"}
      assert request["text"]["verbosity"] == "low"
      assert request["text"]["format"]["type"] == "json_schema"
      assert get_in(request, ["text", "format", "schema", "properties", "cta", "anyOf"]) != nil

      website_payload_schema =
        get_in(request, [
          "text",
          "format",
          "schema",
          "properties",
          "cta",
          "anyOf",
          Access.at(1),
          "properties",
          "payload"
        ])

      assert Enum.sort(website_payload_schema["required"]) == [
               "body",
               "image_url",
               "title",
               "url"
             ]

      assert get_in(website_payload_schema, ["properties", "title", "anyOf", Access.at(1), "type"]) ==
               "null"

      Req.Test.json(conn, %{
        "output" => [
          %{
            "type" => "message",
            "role" => "assistant",
            "content" => [
              %{
                "type" => "output_text",
                "text" =>
                  ~s({"reply":"Yes, tomatoes are available.","cta":{"type":"website","payload":{"url":"https://shop.example.com"}}})
              }
            ]
          }
        ],
        "usage" => %{"input_tokens" => 120, "output_tokens" => 40, "total_tokens" => 160}
      })
    end)

    Process.put(:openai_req_options, plug: {Req.Test, __MODULE__.JsonReplyStub})

    assert {:ok, result} =
             OpenAIClient.chat(
               [%{role: "user", content: "Do you have tomatoes?"}],
               "System prompt"
             )

    assert result.reply == "Yes, tomatoes are available."

    assert result.cta == %{
             "type" => "website",
             "payload" => %{"url" => "https://shop.example.com"}
           }

    assert result.tokens == 160
  end

  test "chat/2 falls back to raw text when JSON parsing fails" do
    Req.Test.expect(__MODULE__.TextReplyStub, fn conn ->
      Req.Test.json(conn, %{
        "output" => [
          %{
            "type" => "message",
            "role" => "assistant",
            "content" => [%{"type" => "output_text", "text" => "Sorry, I do not know that yet."}]
          }
        ],
        "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
      })
    end)

    Process.put(:openai_req_options, plug: {Req.Test, __MODULE__.TextReplyStub})

    assert {:ok, result} =
             OpenAIClient.chat([%{"role" => "user", "content" => "Question"}], "System prompt")

    assert result.reply == "Sorry, I do not know that yet."
    assert result.cta == nil
    assert result.tokens == 15
  end

  test "chat/2 returns an error tuple for non-2xx responses" do
    Req.Test.expect(__MODULE__.ErrorStub, fn conn ->
      Plug.Conn.resp(conn, 401, ~s({"error":{"message":"invalid api key"}}))
    end)

    Process.put(:openai_req_options, plug: {Req.Test, __MODULE__.ErrorStub})

    assert {:error, reason} =
             OpenAIClient.chat([%{role: "user", content: "Hello"}], "System prompt")

    assert reason =~ "HTTP 401"
    assert reason =~ "invalid api key"
  end
end
