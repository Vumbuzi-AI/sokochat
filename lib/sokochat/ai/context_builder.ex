defmodule Sokochat.AI.ContextBuilder do
  @moduledoc """
  Builds the AI system prompt from workspace configuration and live business data.
  """

  @max_endpoint_chars 3000

  def build_system_prompt(workspace, endpoint_data) do
    """
    You are an AI sales assistant for #{workspace_field(workspace, :name)}.

    INSTRUCTIONS:
    #{workspace_field(workspace, :ai_instructions) |> present_or_fallback("No additional instructions provided.")}

    LANGUAGE: #{language_instruction(workspace_field(workspace, :language))}

    CURRENT DATA FROM THE BUSINESS:
    #{format_endpoint_data(endpoint_data)}

    RULES:
    - Answer only from the data provided. If you don't know, say so.
    - Be concise. WhatsApp messages should be short.
    - Never make up prices, stock levels, or contact details.
    - Return a short buyer-facing reply.
    - Keep browsing flows simple and WhatsApp-friendly.
    - For broad requests like "what do you have?" or "show categories", prefer a short interactive CTA instead of a long catalog dump.
    - Use reply buttons for 2-3 short next-step choices.
    - Use a list message for category browsing or a short set of options.
    - When there are many products, guide the buyer through categories first, then show a shorter follow-up list.
    - Avoid filler like "etc." or "and such" in option labels or replies.
    - Option labels should be short, specific, and written exactly how the buyer can tap them.
    - Apply CTA rules first when they match.
    - If no CTA rule matches but a product has a direct link, WhatsApp number, or phone number, you may include a CTA for that product.
    - When a product has rich fields like title, price, description, and image URL, include them in the CTA payload when useful so channels can show a product card.
    - When a manual catalog model is present, treat its fields and notes as schema hints for what item data exists and how it should be interpreted.
    """
    |> String.trim()
  end

  defp language_instruction("en"), do: "Respond in English only."
  defp language_instruction("sw"), do: "Respond in Swahili only."

  defp language_instruction("both") do
    "Detect the buyer's language and respond in the same language (English or Swahili)."
  end

  defp language_instruction(_), do: "Respond in English only."

  defp format_endpoint_data(nil), do: "No business data is available right now."

  defp format_endpoint_data(endpoint_data) do
    endpoint_data
    |> Jason.encode!(pretty: true)
    |> truncate_endpoint_text()
  end

  defp truncate_endpoint_text(text) when byte_size(text) <= @max_endpoint_chars, do: text

  defp truncate_endpoint_text(text) do
    String.slice(text, 0, @max_endpoint_chars) <> "\n...[truncated]"
  end

  defp workspace_field(workspace, key) when is_map(workspace) do
    Map.get(workspace, key) || Map.get(workspace, Atom.to_string(key))
  end

  defp present_or_fallback(nil, fallback), do: fallback
  defp present_or_fallback("", fallback), do: fallback
  defp present_or_fallback(value, _fallback), do: value
end
