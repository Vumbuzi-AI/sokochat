defmodule Sokochat.Marketplace.Chat do
  @moduledoc "Trusted marketplace interactions. Order confirmation never comes from the model."
  alias Sokochat.{Marketplace, Meta}
  alias Sokochat.Marketplace.Orders
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
      {:ok, order} ->
        answer(
          "Send an order request to #{order.product["seller_name"]} for 1 × #{order.product["title"]}? #{price_text(order.product)}. The merchant will contact you on this number to confirm size, stock, delivery and payment. No payment has been taken.",
          buttons([
            {"confirm:#{order.id}", "Confirm request"},
            {"browse:categories", "Keep shopping"}
          ])
        )

      _ ->
        unavailable(workspace)
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

      {:error, :expired} ->
        answer(
          "This request has expired. Choose the product again to check its current availability.",
          Marketplace.category_cta(workspace)
        )

      _ ->
        unavailable(workspace)
    end
  end

  defp interaction(workspace, _phone, _text, "browse:categories", _key, _preferred),
    do: answer("What would you like to shop for?", Marketplace.category_cta(workspace))

  defp interaction(workspace, _phone, text, _id, _key, preferred) do
    if greeting?(text), do: Marketplace.welcome(workspace, preferred), else: nil
  end

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
