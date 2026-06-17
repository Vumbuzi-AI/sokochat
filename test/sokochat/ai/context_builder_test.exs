defmodule Sokochat.AI.ContextBuilderTest do
  use ExUnit.Case, async: true

  alias Sokochat.AI.ContextBuilder
  alias Sokochat.Workspaces.Workspace

  test "build_system_prompt/2 includes workspace instructions and language mapping" do
    workspace = %Workspace{
      name: "Sokopawa",
      ai_instructions: "Be friendly and concise.",
      language: "both"
    }

    prompt =
      ContextBuilder.build_system_prompt(workspace, %{
        "products" => [%{"name" => "Tomatoes", "price" => 100}]
      })

    assert prompt =~ "You are an AI sales assistant for Sokopawa."
    assert prompt =~ "Be friendly and concise."
    assert prompt =~ "Detect the buyer's language and respond in the same language"
    assert prompt =~ "\"name\": \"Tomatoes\""
    assert prompt =~ "\"price\": 100"
    assert prompt =~ "Apply CTA rules first when they match."
    assert prompt =~ "include them in the CTA payload"
  end

  test "build_system_prompt/2 truncates large endpoint data" do
    workspace = %Workspace{name: "Sokopawa", ai_instructions: "", language: "en"}
    long_text = String.duplicate("x", 4000)

    prompt = ContextBuilder.build_system_prompt(workspace, %{"description" => long_text})

    assert prompt =~ "...[truncated]"
    assert prompt =~ "Respond in English only."
  end

  describe "category awareness" do
    @data %{
      "api_data" => %{
        "data" => [
          %{"category" => "Textiles & linens", "title" => "Hairnet"},
          %{"category" => "Sports, arts & outdoors", "title" => "Volleyball"},
          %{"category" => "Sports, arts & outdoors", "title" => "Rugby Ball"},
          %{"category" => "Fashion", "title" => "Beach Bag"},
          %{"category" => "fashion", "title" => "Tote Bag"},
          %{"category" => nil, "title" => "Unknown"}
        ]
      }
    }

    test "extract_categories/1 returns a deduped, sorted, complete list" do
      assert ContextBuilder.extract_categories(@data) ==
               ["Fashion", "Sports, arts & outdoors", "Textiles & linens"]
    end

    test "build_system_prompt/2 lists every category with counts" do
      workspace = %Workspace{name: "Sokopawa", ai_instructions: "", language: "en"}
      prompt = ContextBuilder.build_system_prompt(workspace, @data)

      assert prompt =~ "- Fashion (2)"
      assert prompt =~ "- Sports, arts & outdoors (2)"
      assert prompt =~ "- Textiles & linens (1)"
    end

    test "detect_focus_category/2 matches a category token in the buyer message" do
      assert ContextBuilder.detect_focus_category(@data, "show me sports stuff") ==
               "Sports, arts & outdoors"

      assert ContextBuilder.detect_focus_category(@data, "Textiles please") ==
               "Textiles & linens"

      assert ContextBuilder.detect_focus_category(@data, "hello there") == nil
    end

    test "build_system_prompt/3 with focus_category streams only that category's products" do
      workspace = %Workspace{name: "Sokopawa", ai_instructions: "", language: "en"}

      prompt =
        ContextBuilder.build_system_prompt(workspace, @data,
          focus_category: "Sports, arts & outdoors"
        )

      assert prompt =~ "showing only the \"Sports, arts & outdoors\" category"
      assert prompt =~ "Volleyball"
      assert prompt =~ "Rugby Ball"
      refute prompt =~ "Hairnet"
      refute prompt =~ "Beach Bag"
    end
  end
end
