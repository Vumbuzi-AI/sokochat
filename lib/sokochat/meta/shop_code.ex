defmodule Sokochat.Meta.ShopCode do
  @moduledoc """
  Parses and strips `[shop:code]` tokens from inbound WhatsApp text, and
  recognizes interactive reply ids of the form `shop:code`.
  """

  @token_regex ~r/\[shop:([a-z0-9]+(?:-[a-z0-9]+)*)\]/i
  @id_regex ~r/\Ashop:([a-z0-9]+(?:-[a-z0-9]+)*)\z/i

  @doc """
  Extracts a shop code from an interactive reply id, if present.

  Returns `{:ok, code}` or `:none`.
  """
  def from_reply_id(id) when is_binary(id) do
    case Regex.run(@id_regex, String.trim(id)) do
      [_, code] -> {:ok, String.downcase(code)}
      _ -> :none
    end
  end

  def from_reply_id(_), do: :none

  @doc """
  Finds a `[shop:code]` token in text, strips it, and returns the cleaned
  remainder.

  An empty remainder becomes `"Hello"` so the shop bot still greets.
  Returns `{:ok, code, cleaned_text}` or `:none`.
  """
  def extract(text) when is_binary(text) do
    case Regex.run(@token_regex, text, capture: :all_but_first) do
      [code] ->
        cleaned =
          text
          |> String.replace(@token_regex, " ")
          |> String.replace(~r/\s+/, " ")
          |> String.trim()

        cleaned = if cleaned == "", do: "Hello", else: cleaned
        {:ok, String.downcase(code), cleaned}

      _ ->
        :none
    end
  end

  def extract(_), do: :none
end
