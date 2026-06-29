defmodule Sokochat.AI.CtaRecommender do
  @moduledoc """
  Asks the model to propose CTA rules for a workspace based on its company profile
  and product/business context. Returns suggestions in the same attribute shape that
  `Sokochat.CTARules.create_cta_rule/2` accepts (minus `priority`, which the caller
  assigns), so the user can review and add them one by one.
  """

  alias Sokochat.AI.OpenAIClient
  alias Sokochat.CTARules.CTARule

  @max_context_chars 4000

  @doc """
  Returns `{:ok, [%{"trigger_description" => ..., "cta_type" => ..., "cta_payload" => map}]}`
  or `{:error, reason}`.
  """
  def recommend(workspace, business_context) do
    input = [%{role: "user", content: user_prompt(workspace, business_context)}]

    with {:ok, %{text: text}} <-
           OpenAIClient.structured_completion(instructions(), input, response_format()),
         {:ok, %{"suggestions" => suggestions}} when is_list(suggestions) <- Jason.decode(text) do
      {:ok, parse_suggestions(suggestions)}
    else
      {:ok, _decoded} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp instructions do
    """
    You design WhatsApp call-to-action (CTA) rules for a sales assistant.

    Given a company profile and its product/business data, propose up to 5 CTA rules
    that would help buyers take the next step. Each rule has:
    - trigger_description: when the assistant should attach this CTA (a buyer intent).
    - cta_type: one of #{Enum.join(CTARule.cta_types(), ", ")}.
    - cta_payload_json: a JSON-encoded object whose fields match the cta_type:
      - website        -> {"url": "https://..."}
      - phone          -> {"number": "+254..."}   (use the company phone if available)
      - whatsapp       -> {"number": "+254..."}   (use the company phone if available)
      - reply_buttons  -> {"buttons": ["Label 1", "Label 2"]}  (1-3 short labels)
      - list_message   -> {"items": [{"title": "...", "description": "..."}]}  (1-6 rows)
      - location       -> {"latitude": -1.29, "longitude": 36.82}  (use the company location)
      - catalog        -> {"product_id": "sku_123"}
      - custom         -> {"template": "free-form message"}

    Rules:
    - Only suggest a phone/whatsapp/location CTA if the relevant company detail exists.
    - Keep trigger_description specific and at least 5 characters.
    - Ground suggestions in the actual products and profile; do not invent prices or links.
    - Prefer a small, high-value set of rules over many generic ones.
    """
    |> String.trim()
  end

  defp user_prompt(workspace, business_context) do
    """
    COMPANY PROFILE:
    #{profile_block(workspace)}

    PRODUCT / BUSINESS DATA:
    #{format_context(business_context)}
    """
    |> String.trim()
  end

  defp profile_block(workspace) do
    [
      {"Workspace", Map.get(workspace, :name)},
      {"Company", Map.get(workspace, :company_name)},
      {"Industry", Map.get(workspace, :industry)},
      {"Location", Map.get(workspace, :location)},
      {"Phone", Map.get(workspace, :phone_number)},
      {"About", Map.get(workspace, :about)}
    ]
    |> Enum.reject(fn {_label, value} -> value in [nil, ""] end)
    |> case do
      [] -> "No company profile provided."
      entries -> Enum.map_join(entries, "\n", fn {label, value} -> "- #{label}: #{value}" end)
    end
  end

  defp format_context(nil), do: "No product data available."

  defp format_context(context) do
    context
    |> Jason.encode!(pretty: true)
    |> truncate()
  end

  defp truncate(text) when byte_size(text) <= @max_context_chars, do: text
  defp truncate(text), do: String.slice(text, 0, @max_context_chars) <> "\n...[truncated]"

  defp parse_suggestions(suggestions) do
    suggestions
    |> Enum.map(&parse_suggestion/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_suggestion(%{
         "trigger_description" => trigger,
         "cta_type" => cta_type,
         "cta_payload_json" => payload_json
       })
       when is_binary(trigger) and is_binary(cta_type) and is_binary(payload_json) do
    with true <- cta_type in CTARule.cta_types(),
         {:ok, payload} when is_map(payload) and map_size(payload) > 0 <-
           Jason.decode(payload_json) do
      %{
        "trigger_description" => String.trim(trigger),
        "cta_type" => cta_type,
        "cta_payload" => payload
      }
    else
      _ -> nil
    end
  end

  defp parse_suggestion(_other), do: nil

  defp response_format do
    %{
      type: "json_schema",
      name: "cta_rule_suggestions",
      strict: true,
      schema: %{
        type: "object",
        additionalProperties: false,
        required: ["suggestions"],
        properties: %{
          suggestions: %{
            type: "array",
            minItems: 0,
            maxItems: 6,
            items: %{
              type: "object",
              additionalProperties: false,
              required: ["trigger_description", "cta_type", "cta_payload_json"],
              properties: %{
                trigger_description: %{type: "string"},
                cta_type: %{type: "string", enum: CTARule.cta_types()},
                cta_payload_json: %{type: "string"}
              }
            }
          }
        }
      }
    }
  end
end
