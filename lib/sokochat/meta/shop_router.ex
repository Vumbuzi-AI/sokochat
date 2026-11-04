defmodule Sokochat.Meta.ShopRouter do
  @moduledoc """
  Resolves which shop workspace should handle an inbound message on a shared
  WhatsApp line.

  Resolution order:
  1. `[shop:code]` in the text, or interactive id `shop:code`
  2. Existing binding for this buyer on the line
  3. Otherwise return a shop picker (no AI dispatch)
  """

  alias Sokochat.Meta
  alias Sokochat.Meta.SharedLine
  alias Sokochat.Meta.ShopCode
  alias Sokochat.Workspaces.Workspace

  @type route_result ::
          {:dispatch, Workspace.t(), String.t(), keyword()}
          | {:picker, String.t() | nil, list_message :: map()}

  @doc """
  Routes an inbound message on `shared_line`.

  `message_text` is the visible body. `reply_id` is the interactive button/list
  id when present.
  """
  @spec route(SharedLine.t(), String.t(), String.t(), String.t() | nil) :: route_result()
  def route(%SharedLine{} = shared_line, phone_number, message_text, reply_id \\ nil) do
    shops = Meta.list_shared_line_shops(shared_line.id)
    explicit = explicit_code(message_text, reply_id)

    case explicit do
      {:ok, code, cleaned} ->
        route_explicit(shared_line, phone_number, code, cleaned, shops)

      :none ->
        route_without_code(shared_line, phone_number, message_text, shops)
    end
  end

  defp explicit_code(message_text, reply_id) do
    case ShopCode.from_reply_id(reply_id) do
      {:ok, code} ->
        cleaned =
          if is_binary(message_text) and String.trim(message_text) != "" do
            String.trim(message_text)
          else
            "Hello"
          end

        {:ok, code, cleaned}

      :none ->
        ShopCode.extract(message_text)
    end
  end

  defp route_explicit(shared_line, phone_number, code, cleaned, shops) do
    case Enum.find(shops, &(&1.shop_code == code)) do
      %Workspace{} = shop ->
        previous = Meta.get_shop_binding(shared_line.id, phone_number)
        {:ok, _binding} = Meta.upsert_shop_binding(shared_line.id, phone_number, shop.id)

        opts =
          if previous && previous.workspace_id != shop.id do
            [switch_notice: "You're now with #{shop.name}."]
          else
            []
          end

        {:dispatch, shop, cleaned, opts}

      nil ->
        {:picker, "That shop wasn't recognized. Please pick one:", picker_payload(shops)}
    end
  end

  defp route_without_code(shared_line, phone_number, message_text, shops) do
    case Meta.get_shop_binding_with_workspace(shared_line.id, phone_number) do
      %{workspace: %Workspace{shared_line_id: line_id} = shop}
      when line_id == shared_line.id ->
        {:dispatch, shop, message_text, []}

      _ ->
        {:picker, nil, picker_payload(shops)}
    end
  end

  defp picker_payload([]) do
    %{
      "type" => "list_message",
      "payload" => %{
        "title" => "Shops",
        "body" => "No shops are available on this line yet.",
        "items" => []
      }
    }
  end

  defp picker_payload(shops) do
    items =
      Enum.map(shops, fn shop ->
        %{
          "id" => "shop:#{shop.shop_code}",
          "title" => shop.name,
          "description" => shop.shop_code
        }
      end)

    %{
      "type" => "list_message",
      "payload" => %{
        "title" => "Choose a shop",
        "body" => "Which shop would you like to talk to?",
        "items" => items
      }
    }
  end
end
