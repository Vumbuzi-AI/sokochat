defmodule Sokochat.AI.ContextBuilder do
  @moduledoc """
  Builds the AI system prompt from workspace configuration and live business data.
  """

  @max_endpoint_chars 3000

  def build_system_prompt(workspace, endpoint_data, opts \\ []) do
    focus_category = Keyword.get(opts, :focus_category)
    # When retrieval only surfaces a slice of items (RAG), callers pass the
    # complete category list explicitly so browsing flows stay accurate.
    all_categories = Keyword.get(opts, :all_categories)

    """
    You are an AI sales assistant for #{workspace_field(workspace, :name)}.

    BUSINESS PROFILE:
    #{business_profile(workspace)}

    INSTRUCTIONS:
    #{workspace_field(workspace, :ai_instructions) |> present_or_fallback("No additional instructions provided.")}

    LANGUAGE: #{language_instruction(workspace_field(workspace, :language))}

    PRODUCT CATEGORIES (complete list — use these for category browsing):
    #{format_categories(endpoint_data, all_categories)}

    #{data_section(endpoint_data, focus_category)}

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
    - When offering categories to browse, use the complete PRODUCT CATEGORIES list above, not only the categories that happen to appear in the data sample below.
    - Avoid filler like "etc." or "and such" in option labels or replies.
    - Option labels should be short, specific, and written exactly how the buyer can tap them.
    - Apply CTA rules first when they match.
    - If no CTA rule matches but a product has a direct link, WhatsApp number, or phone number, you may include a CTA for that product.
    - When a product has rich fields like title, price, description, and image URL, include them in the CTA payload when useful so channels can show a product card.
    - When a manual catalog model is present, treat its fields and notes as schema hints for what item data exists and how it should be interpreted.
    """
    |> String.trim()
  end

  defp business_profile(workspace) do
    [
      {"Company", workspace_field(workspace, :company_name)},
      {"Industry", workspace_field(workspace, :industry)},
      {"Location", workspace_field(workspace, :location)},
      {"Phone", workspace_field(workspace, :phone_number)},
      {"About", workspace_field(workspace, :about)}
    ]
    |> Enum.reject(fn {_label, value} -> value in [nil, ""] end)
    |> case do
      [] -> "No company profile provided yet."
      entries -> Enum.map_join(entries, "\n", fn {label, value} -> "- #{label}: #{value}" end)
    end
  end

  defp language_instruction("en"), do: "Respond in English only."
  defp language_instruction("sw"), do: "Respond in Swahili only."

  defp language_instruction("both") do
    "Detect the buyer's language and respond in the same language (English or Swahili)."
  end

  defp language_instruction(_), do: "Respond in English only."

  # When an explicit category list is supplied (RAG path), list those names
  # directly — the retrieved data slice is too small to derive counts from.
  defp format_categories(_endpoint_data, categories)
       when is_list(categories) and categories != [] do
    Enum.map_join(categories, "\n", fn category -> "- #{category}" end)
  end

  defp format_categories(endpoint_data, _categories), do: format_categories(endpoint_data)

  defp format_categories(endpoint_data) do
    case category_counts(endpoint_data) do
      [] ->
        "No categories detected in the current data."

      counts ->
        Enum.map_join(counts, "\n", fn {category, count} -> "- #{category} (#{count})" end)
    end
  end

  defp category_counts(endpoint_data) do
    products = collect_products(endpoint_data)

    extract_categories(endpoint_data)
    |> Enum.map(fn category ->
      {category, Enum.count(products, &product_in_category?(&1, category))}
    end)
  end

  # Builds the CURRENT DATA section. When the buyer has homed in on a category,
  # only that category's products are streamed (in full), so detail is never lost
  # to truncation. Otherwise the whole catalog is dumped (and truncated if large).
  defp data_section(nil, _focus_category) do
    "CURRENT DATA FROM THE BUSINESS:\n" <> format_endpoint_data(nil)
  end

  defp data_section(endpoint_data, focus_category)
       when is_binary(focus_category) and focus_category != "" do
    case Enum.filter(collect_products(endpoint_data), &product_in_category?(&1, focus_category)) do
      [] ->
        data_section(endpoint_data, nil)

      products ->
        "CURRENT DATA FROM THE BUSINESS (showing only the \"#{focus_category}\" category — " <>
          "#{length(products)} product(s)):\n" <> format_endpoint_data(products)
    end
  end

  defp data_section(endpoint_data, _focus_category) do
    "CURRENT DATA FROM THE BUSINESS:\n" <> format_endpoint_data(endpoint_data)
  end

  @doc """
  Detects which catalog category the buyer's message is asking about, if any.

  Returns the matching category string (as stored in the data) or `nil`.
  """
  def detect_focus_category(endpoint_data, message) when is_binary(message) do
    normalized = String.downcase(message)

    endpoint_data
    |> extract_categories()
    |> Enum.filter(&category_mentioned?(&1, normalized))
    # Prefer the most specific (longest) matching category name.
    |> Enum.sort_by(&String.length/1, :desc)
    |> List.first()
  end

  def detect_focus_category(_endpoint_data, _message), do: nil

  defp category_mentioned?(category, normalized_message) do
    category
    |> category_match_terms()
    |> Enum.any?(&String.contains?(normalized_message, &1))
  end

  # A category like "Sports, arts & outdoors" should match "sports", "arts",
  # or "outdoors", not just the full punctuated string a buyer would never type.
  defp category_match_terms(category) do
    full = String.downcase(String.trim(category))

    tokens =
      full
      |> String.split(~r/[^\p{L}\p{N}]+/u, trim: true)
      |> Enum.reject(&(&1 in ~w(and the of with for) or String.length(&1) < 3))

    [full | tokens]
    |> Enum.uniq()
  end

  defp collect_products(data) when is_list(data), do: Enum.flat_map(data, &collect_products/1)

  defp collect_products(data) when is_map(data) do
    nested = data |> Map.values() |> Enum.flat_map(&collect_products/1)
    if product_category(data), do: [data | nested], else: nested
  end

  defp collect_products(_data), do: []

  defp product_category(product) when is_map(product) do
    case Map.get(product, "category") || Map.get(product, :category) do
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  defp product_category(_), do: nil

  defp product_in_category?(product, category) do
    case product_category(product) do
      nil -> false
      value -> String.downcase(String.trim(value)) == String.downcase(String.trim(category))
    end
  end

  @doc false
  def extract_categories(data) do
    data
    |> collect_categories()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.sort_by(&String.downcase/1)
  end

  defp collect_categories(data) when is_list(data) do
    Enum.flat_map(data, &collect_categories/1)
  end

  defp collect_categories(data) when is_map(data) do
    own =
      [Map.get(data, "category"), Map.get(data, :category)]
      |> Enum.filter(&is_binary/1)

    nested = data |> Map.values() |> Enum.flat_map(&collect_categories/1)
    own ++ nested
  end

  defp collect_categories(_data), do: []

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
