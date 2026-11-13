defmodule Sokochat.Marketplace.Chat do
  @moduledoc "Trusted marketplace interactions. Order confirmation never comes from the model."
  alias Sokochat.{Marketplace, Meta}
  alias Sokochat.Marketplace.{Fulfillment, Orders}
  alias Sokochat.Meta.ShopCode

  def route(line, phone, text, reply_id, source_key) do
    with {:ok, workspace} <- Marketplace.ensure_workspace(line) do
      text =
        case reply_id do
          "category:" <> category -> "Show me #{category} across all shops"
          _ -> text
        end

      {preferred, text} = preference(line, phone, text, reply_id)
      reply = interaction(workspace, phone, text, reply_id, source_key, preferred)
      {:dispatch, workspace, text, [preferred_shop: preferred, marketplace_reply: reply]}
    end
  end

  defp preference(line, phone, text, reply_id) do
    explicit =
      case ShopCode.from_reply_id(reply_id) do
        {:ok, code} -> {:ok, code, ShopCode.catalog_opener()}
        :none -> ShopCode.extract(text)
      end

    case explicit do
      {:ok, code, cleaned} ->
        case Meta.get_shop_by_code(line.id, code) do
          %{marketplace: false} = shop ->
            {:ok, _} = Meta.upsert_shop_binding(line.id, phone, shop.id)

            {shop,
             if(String.trim(cleaned) == "", do: "Show me this shop's products", else: cleaned)}

          _ ->
            {nil, text}
        end

      :none ->
        shop =
          case Meta.get_shop_binding_with_workspace(line.id, phone) do
            %{workspace: %{shared_line_id: id, marketplace: false} = shop} when id == line.id ->
              shop

            _ ->
              nil
          end

        {shop, text}
    end
  end

  defp interaction(workspace, _phone, _text, "product:" <> id, _source_key, _preferred) do
    case Marketplace.get_product(workspace, id) do
      nil -> unavailable(workspace)
      item -> product_reply(item)
    end
  end

  defp interaction(workspace, phone, _text, "request:" <> id, source_key, _preferred) do
    case Orders.draft(workspace, phone, id, source_key) do
      {:ok, %{status: "draft"} = order} ->
        Orders.cancel_address(workspace, phone)
        fulfillment_choices(workspace, phone, order)

      {:ok, order} ->
        answer(
          "Order request ##{order.id} has already been sent.",
          Marketplace.category_cta(workspace)
        )

      _ ->
        unavailable(workspace)
    end
  end

  defp interaction(workspace, phone, _text, "fulfill:" <> selection, _key, _preferred) do
    case String.split(selection, ":", parts: 2) do
      [id, "delivery"] ->
        with {:ok, order} <- Orders.get_draft(workspace, phone, id) do
          delivery_areas(workspace, order)
        else
          _ -> unavailable(workspace)
        end

      [id, choice] ->
        Orders.cancel_address(workspace, phone)

        case Orders.set_fulfillment(workspace, phone, id, fn order ->
               Fulfillment.build_quote(Fulfillment.shop(order), choice)
             end) do
          {:ok, %{fulfillment: %{"awaiting_address" => true}} = order} ->
            answer(
              "#{Fulfillment.summary(order.fulfillment)}\nSend your delivery address, including building and a nearby landmark. For an unlisted area, include your town or neighbourhood. This goes only to #{order.product["seller_name"]} with this order request.",
              buttons([{"browse:categories", "Keep shopping"}])
            )

          {:ok, order} ->
            review_order(order)

          _ ->
            answer(
              "That option is no longer available. Open the product and request it again.",
              Marketplace.category_cta(workspace)
            )
        end

      _ ->
        unavailable(workspace)
    end
  end

  defp interaction(workspace, phone, _text, "fulfillment:" <> id, _key, _preferred) do
    Orders.cancel_address(workspace, phone)

    case Orders.get_draft(workspace, phone, id) do
      {:ok, order} -> fulfillment_choices(workspace, phone, order)
      _ -> unavailable(workspace)
    end
  end

  defp interaction(workspace, phone, _text, "confirm:" <> id, _key, _preferred) do
    case Orders.confirm(workspace, phone, id) do
      {:ok, order} ->
        answer(
          "Order request ##{order.id} sent to #{order.product["seller_name"]}. They’ll follow up on this WhatsApp number. What else would you like to shop for?",
          Marketplace.category_cta(workspace)
        )

      {:error, :changed} ->
        answer(
          "This product has changed. Open it again to review the current details before requesting it.",
          Marketplace.category_cta(workspace)
        )

      {:error, :fulfillment_changed} ->
        answer(
          "Choose collection or delivery again to review the current details and charges before confirming.",
          buttons([
            {"fulfillment:#{id}", "Choose option"},
            {"browse:categories", "Keep shopping"}
          ])
        )

      {:error, :expired} ->
        answer(
          "This request has expired. Choose the product again to check its current availability.",
          Marketplace.category_cta(workspace)
        )

      _ ->
        unavailable(workspace)
    end
  end

  defp interaction(workspace, phone, _text, "browse:categories", _key, _preferred) do
    Orders.cancel_address(workspace, phone)
    answer("What would you like to shop for?", Marketplace.category_cta(workspace))
  end

  defp interaction(workspace, phone, text, _id, _key, preferred) do
    cond do
      greeting?(text) ->
        Marketplace.welcome(workspace, preferred)

      order = Orders.pending_address(workspace, phone) ->
        capture_address(workspace, phone, order, text)

      true ->
        nil
    end
  end

  defp fulfillment_choices(workspace, phone, order) do
    shop = Fulfillment.shop(order)

    if Fulfillment.configured?(shop) do
      choices = []

      choices =
        if shop.pickup_enabled,
          do: choices ++ [{"fulfill:#{order.id}:pickup", "Collect in store"}],
          else: choices

      choices =
        if shop.delivery_enabled,
          do: choices ++ [{"fulfill:#{order.id}:delivery", "Delivery"}],
          else: choices

      answer(
        "For #{order.product["title"]} from #{order.product["seller_name"]}, would you like delivery or to collect in store? Choose an available option.",
        buttons(choices ++ [{"browse:categories", "Keep shopping"}])
      )
    else
      case Orders.set_fulfillment(workspace, phone, order.id, fn _ ->
             Fulfillment.build_quote(shop, "merchant")
           end) do
        {:ok, order} -> review_order(order)
        _ -> unavailable(workspace)
      end
    end
  end

  defp delivery_areas(_workspace, order) do
    shop = Fulfillment.shop(order)

    rows =
      if shop.delivery_enabled,
        do:
          Enum.map(shop.delivery_rates, fn rate ->
            %{
              "id" => "fulfill:#{order.id}:#{rate.id}",
              "title" => String.slice(rate.area, 0, 24),
              "description" => "Delivery: KES #{Decimal.to_string(rate.fee)}"
            }
          end),
        else: []

    rows =
      if shop.delivery_enabled && shop.delivery_quote_outside,
        do:
          rows ++
            [
              %{
                "id" => "fulfill:#{order.id}:other",
                "title" => "Other area",
                "description" => "Delivery fee to be confirmed by seller"
              }
            ],
        else: rows

    if rows == [] do
      answer(
        "Delivery is not available for this shop right now.",
        buttons([
          {"fulfillment:#{order.id}", "Choose option"},
          {"browse:categories", "Keep shopping"}
        ])
      )
    else
      answer(
        "Where should #{order.product["seller_name"]} deliver your order? Choose an area to see the charge.",
        %{
          "type" => "list_message",
          "payload" => %{
            "title" => "Delivery areas",
            "items" => rows
          }
        }
      )
    end
  end

  defp capture_address(workspace, phone, order, text) do
    address = String.trim(text)

    if String.length(address) < 8 || String.length(address) > 500 do
      answer(
        "Please send an address of 8–500 characters, including your town, building and a nearby landmark.",
        buttons([{"browse:categories", "Keep shopping"}])
      )
    else
      case Orders.set_fulfillment(workspace, phone, order.id, fn current ->
             if current.fulfillment && current.fulfillment["awaiting_address"] do
               {:ok,
                current.fulfillment
                |> Map.put("address", address)
                |> Map.put("awaiting_address", false)}
             else
               {:error, :unavailable}
             end
           end) do
        {:ok, order} -> review_order(order)
        _ -> unavailable(workspace)
      end
    end
  end

  defp review_order(order) do
    summary = Fulfillment.summary(order.fulfillment)
    estimate = estimated_total(order.product, order.fulfillment)

    answer(
      "Send an order request to #{order.product["seller_name"]} for 1 × #{order.product["title"]}? #{price_text(order.product)}.\n#{summary}#{estimate}\nThe seller confirms size, stock and payment. No payment has been taken.",
      buttons([
        {"confirm:#{order.id}", "Confirm request"},
        {"fulfillment:#{order.id}", "Change option"},
        {"browse:categories", "Keep shopping"}
      ])
    )
  end

  defp estimated_total(product, %{"fee" => fee}) when is_binary(fee) do
    prices = (product["variants"] || []) |> Enum.map(& &1["price"]) |> Enum.filter(&is_number/1)
    prices = if prices == [] && is_number(product["price"]), do: [product["price"]], else: prices

    if prices == [],
      do: "",
      else:
        "\nEstimated total from KES #{Decimal.add(Decimal.new(to_string(Enum.min(prices))), Decimal.new(fee)) |> Decimal.to_string()}."
  end

  defp estimated_total(_, _), do: ""

  def greeting?(text),
    do: String.downcase(String.trim(text)) in ~w(hi hello hey hiya jambo habari)

  def prepare_preview(%{marketplace: true} = workspace, phone, text, reply_id) do
    line = Sokochat.Repo.get!(Sokochat.Meta.SharedLine, workspace.shared_line_id)

    {preferred, cleaned} =
      preference(line, phone, preview_text(workspace, text, reply_id), reply_id)

    {cleaned, [preferred_shop: preferred, marketplace_reply: preview_reply(workspace, reply_id)]}
  end

  def prepare_preview(_workspace, _phone, text, _reply_id), do: {text, []}

  def preview_text(%{marketplace: true}, _text, "category:" <> category),
    do: "Show me #{category} across all shops"

  def preview_text(_workspace, text, _id), do: text

  def preview_reply(%{marketplace: true} = workspace, "product:" <> id) do
    case Marketplace.get_product(workspace, id) do
      nil -> unavailable(workspace)
      item -> product_reply(item)
    end
  end

  def preview_reply(%{marketplace: true} = workspace, "browse:categories"),
    do: answer("What would you like to shop for?", Marketplace.category_cta(workspace))

  def preview_reply(%{marketplace: true}, "request:" <> _),
    do:
      answer(
        "Order requests are sent from WhatsApp. This is a test chat; no request has been sent to a merchant.",
        nil
      )

  def preview_reply(%{marketplace: true}, "confirm:" <> _),
    do: answer("This is a test chat; no request has been sent to a merchant.", nil)

  def preview_reply(%{marketplace: true}, "fulfill" <> _),
    do:
      answer(
        "Collection and delivery are selected when ordering on WhatsApp. No request has been sent from this test chat.",
        nil
      )

  def preview_reply(_, _), do: nil

  def product_reply(item) do
    product = Marketplace.product_context(item)

    answer(
      "#{product["title"]} from #{product["seller_name"]}. #{price_text(product)}. The merchant confirms your size or variant and current availability.",
      %{
        "type" => "reply_buttons",
        "payload" => %{
          "title" => product["title"],
          "image_url" => product["image_url"],
          "buttons" => [
            %{"id" => "request:#{item.id}", "title" => "Request order"},
            %{"id" => "browse:categories", "title" => "Keep shopping"}
          ]
        }
      }
    )
  end

  def price_text(product) do
    prices =
      (product["variants"] || [])
      |> Enum.flat_map(fn
        %{"price" => price} when is_number(price) -> [price]
        _ -> []
      end)

    prices = if prices == [] and is_number(product["price"]), do: [product["price"]], else: prices

    case prices do
      [] -> "Price to confirm with merchant"
      prices -> "From #{product["currency"] || "KES"} #{format_price(Enum.min(prices))}"
    end
  end

  defp format_price(price) do
    text =
      if is_float(price), do: :erlang.float_to_binary(price, decimals: 2), else: to_string(price)

    [whole | fraction] = String.split(text, ".")
    whole = Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, whole, ",")

    case fraction do
      ["00"] -> whole
      [cents] -> whole <> "." <> cents
      _ -> whole
    end
  end

  defp unavailable(workspace),
    do:
      answer(
        "This product is no longer available here. Browse a category to find another option.",
        Marketplace.category_cta(workspace)
      )

  defp buttons(items),
    do: %{
      "type" => "reply_buttons",
      "payload" => %{
        "buttons" => Enum.map(items, fn {id, title} -> %{"id" => id, "title" => title} end)
      }
    }

  defp answer(reply, cta), do: %{reply: reply, cta: cta, tokens: 0, policy: "ok"}
end
