defmodule Sokochat.AI.CtaRecommenderTest do
  use ExUnit.Case, async: true

  alias Sokochat.AI.CtaRecommender
  alias Sokochat.Workspaces.Workspace

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

  defp workspace do
    %Workspace{
      name: "Acme Shop",
      company_name: "Acme Ltd",
      industry: "Electronics",
      location: "Nairobi",
      phone_number: "+254700000000"
    }
  end

  test "recommend/2 parses suggestions into CTA-rule attributes" do
    Req.Test.expect(__MODULE__.RecommendStub, fn conn ->
      assert conn.method == "POST"

      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert request["text"]["format"]["name"] == "cta_rule_suggestions"
      assert request["instructions"] =~ "CTA"
      assert [%{"role" => "user", "content" => content}] = request["input"]
      assert content =~ "Acme Ltd"

      Req.Test.json(conn, %{
        "output" => [
          %{
            "type" => "message",
            "role" => "assistant",
            "content" => [
              %{
                "type" => "output_text",
                "text" =>
                  Jason.encode!(%{
                    "suggestions" => [
                      %{
                        "trigger_description" => "When a buyer wants to call us",
                        "cta_type" => "phone",
                        "cta_payload_json" => ~s({"number":"+254700000000"})
                      },
                      %{
                        "trigger_description" => "When a buyer asks to browse",
                        "cta_type" => "website",
                        "cta_payload_json" => ~s({"url":"https://acme.example.com"})
                      },
                      %{
                        "trigger_description" => "bad",
                        "cta_type" => "website",
                        "cta_payload_json" => "not json"
                      }
                    ]
                  })
              }
            ]
          }
        ],
        "usage" => %{"input_tokens" => 50, "output_tokens" => 20}
      })
    end)

    Process.put(:openai_req_options, plug: {Req.Test, __MODULE__.RecommendStub})

    assert {:ok, suggestions} = CtaRecommender.recommend(workspace(), %{"products" => []})

    # Invalid (unparseable payload) suggestion is dropped.
    assert [phone, website] = suggestions

    assert phone == %{
             "trigger_description" => "When a buyer wants to call us",
             "cta_type" => "phone",
             "cta_payload" => %{"number" => "+254700000000"}
           }

    assert website["cta_type"] == "website"
    assert website["cta_payload"] == %{"url" => "https://acme.example.com"}
  end

  test "recommend/2 returns an error tuple for non-2xx responses" do
    Req.Test.expect(__MODULE__.ErrorStub, fn conn ->
      Plug.Conn.resp(conn, 500, ~s({"error":{"message":"boom"}}))
    end)

    Process.put(:openai_req_options, plug: {Req.Test, __MODULE__.ErrorStub})

    assert {:error, reason} = CtaRecommender.recommend(workspace(), %{})
    assert reason =~ "HTTP 500"
  end
end
