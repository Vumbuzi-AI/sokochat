defmodule Whatsappbot.Conversations.ProductCTA do
  @moduledoc """
  Builds or enriches product CTAs from endpoint data so channels can render
  a richer product card by default.
  """

  @title_keys ~w(name title product_name productName)
  @description_keys ~w(description short_description shortDescription summary)
  @currency_keys ~w(currency currency_code currencyCode)
  @image_keys ~w(image image_url imageUrl photo photo_url photoUrl thumbnail thumbnail_url thumbnailUrl cover_image cover_image_url coverImage)
  @url_keys ~w(url product_url productUrl checkout_url checkoutUrl link href website)
  @phone_keys ~w(phone phone_number phoneNumber seller_phone sellerPhone contact_phone contactPhone)
  @whatsapp_keys ~w(whatsapp whatsapp_number whatsappNumber seller_whatsapp sellerWhatsapp contact_whatsapp contactWhatsapp)

  def attach(reply_text, user_message, endpoint_data, cta) do
    case best_product(endpoint_data, [reply_text, user_message]) do
      nil -> cta
      product -> maybe_build_or_enrich(cta, product)
    end
  end

  defp maybe_build_or_enrich(nil, product), do: default_cta_for(product)

  defp maybe_build_or_enrich(cta, product) when is_map(cta) do
    type = map_value(cta, "type")
    payload = map_value(cta, "payload") || %{}
    preview = preview_payload(product)

    enriched_payload =
      payload
      |> merge_if_missing(preview)
      |> maybe_put_missing("url", product_url(product), type == "website")
      |> maybe_put_missing("number", product_whatsapp(product), type == "whatsapp")
      |> maybe_put_missing("number", product_phone(product), type == "phone")

    cta
    |> Map.put("type", type)
    |> Map.put("payload", enriched_payload)
  end

  defp maybe_build_or_enrich(cta, _product), do: cta

  defp default_cta_for(product) do
    preview = preview_payload(product)

    cond do
      product_url(product) ->
        %{"type" => "website", "payload" => Map.put(preview, "url", product_url(product))}

      product_whatsapp(product) ->
        %{
          "type" => "whatsapp",
          "payload" => Map.put(preview, "number", product_whatsapp(product))
        }

      product_phone(product) ->
        %{"type" => "phone", "payload" => Map.put(preview, "number", product_phone(product))}

      true ->
        nil
    end
  end

  defp preview_payload(product) do
    %{}
    |> maybe_put("title", product_title(product))
    |> maybe_put("body", product_body(product))
    |> maybe_put("image_url", product_image(product))
  end

  defp best_product(nil, _texts), do: nil

  defp best_product(endpoint_data, texts) do
    products = collect_products(endpoint_data)

    products
    |> Enum.map(&{score_product(&1, texts, length(products) == 1), &1})
    |> Enum.filter(fn {score, _product} -> score > 0 end)
    |> Enum.max_by(fn {score, product} -> {score, preview_richness(product)} end, fn -> nil end)
    |> case do
      nil -> nil
      {_score, product} -> product
    end
  end

  defp collect_products(data) when is_list(data) do
    Enum.flat_map(data, &collect_products/1)
  end

  defp collect_products(data) when is_map(data) do
    nested =
      data
      |> Map.values()
      |> Enum.flat_map(&collect_products/1)

    if product_candidate?(data) do
      [data | nested]
    else
      nested
    end
  end

  defp collect_products(_data), do: []

  defp product_candidate?(product) do
    product_title(product) &&
      (product_url(product) || product_phone(product) || product_whatsapp(product) ||
         product_image(product) || product_body(product))
  end

  defp score_product(product, texts, singleton?) do
    title = normalize_text(product_title(product))
    tokens = title_tokens(title)
    text = normalize_text(Enum.join(Enum.filter(texts, &is_binary/1), " "))
    base_score = if title != "" and String.contains?(text, title), do: 8, else: 0
    token_score = Enum.count(tokens, &String.contains?(text, &1))

    fallback_score =
      if token_score == 0 and singleton? and singleton_product_hint?(product, texts),
        do: 1,
        else: 0

    base_score + token_score + fallback_score + preview_richness(product)
  end

  defp singleton_product_hint?(product, texts) do
    product_title(product) &&
      Enum.any?(texts, fn
        text when is_binary(text) ->
          normalized = normalize_text(text)
          normalized != "" and String.length(normalized) < 80

        _ ->
          false
      end)
  end

  defp preview_richness(product) do
    Enum.count(
      [
        product_image(product),
        product_url(product),
        product_whatsapp(product),
        product_phone(product)
      ],
      & &1
    )
  end

  defp product_title(product), do: first_present(product, @title_keys)
  defp product_image(product), do: first_present(product, @image_keys)
  defp product_url(product), do: first_present(product, @url_keys)
  defp product_phone(product), do: first_present(product, @phone_keys)
  defp product_whatsapp(product), do: first_present(product, @whatsapp_keys)

  defp product_body(product) do
    price = map_value(product, "price")
    currency = first_present(product, @currency_keys)
    description = first_present(product, @description_keys)

    cond do
      not is_nil(price) and currency ->
        "#{currency} #{format_price(price)}"

      not is_nil(price) ->
        format_price(price)

      description ->
        description

      true ->
        nil
    end
  end

  defp first_present(map, keys) do
    Enum.find_value(keys, fn key ->
      case map_value(map, key) do
        value when is_binary(value) ->
          value = String.trim(value)
          if value == "", do: nil, else: value

        value when not is_nil(value) ->
          to_string(value)

        _ ->
          nil
      end
    end)
  end

  defp map_value(map, key) when is_map(map) do
    Map.get(map, key) ||
      case safe_existing_atom(key) do
        nil -> nil
        atom_key -> Map.get(map, atom_key)
      end
  rescue
    ArgumentError -> Map.get(map, key)
  end

  defp map_value(_map, _key), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp merge_if_missing(map, additions) do
    Map.merge(additions, map)
  end

  defp maybe_put_missing(map, _key, _value, false), do: map
  defp maybe_put_missing(map, _key, nil, true), do: map

  defp maybe_put_missing(map, key, value, true) do
    case map_value(map, key) do
      nil -> Map.put(map, key, value)
      "" -> Map.put(map, key, value)
      _existing -> map
    end
  end

  defp title_tokens(""), do: []

  defp title_tokens(title) do
    title
    |> String.split()
    |> Enum.filter(&(String.length(&1) >= 3))
    |> Enum.uniq()
  end

  defp normalize_text(nil), do: ""

  defp normalize_text(text) do
    text
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp format_price(price) when is_integer(price), do: Integer.to_string(price)
  defp format_price(price) when is_float(price), do: :erlang.float_to_binary(price, decimals: 2)
  defp format_price(price), do: to_string(price)

  defp safe_existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
