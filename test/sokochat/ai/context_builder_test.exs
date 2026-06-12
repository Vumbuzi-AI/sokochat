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
end
