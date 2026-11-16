defmodule Sokochat.PhoneNumber do
  @moduledoc "Display and click-to-chat formatting for international WhatsApp sender IDs."

  def format(value) do
    case digits(value) do
      "254" <> <<a::binary-size(3), b::binary-size(3), c::binary-size(3)>> ->
        "+254 #{a} #{b} #{c}"

      "971" <> <<a::binary-size(2), b::binary-size(3), c::binary-size(4)>> ->
        "+971 #{a} #{b} #{c}"

      nil ->
        if is_binary(value) && String.trim(value) != "", do: value, else: "Number unavailable"

      number ->
        "+" <> number
    end
  end

  def whatsapp_url(value) do
    case digits(value) do
      nil -> nil
      number -> "https://wa.me/" <> number
    end
  end

  # WhatsApp sends country-code-prefixed digits. Never assume a country for local numbers,
  # or strip letters from malformed values and accidentally open a different person's chat.
  defp digits(value) when is_binary(value) do
    number = value |> String.trim() |> String.trim_leading("+") |> String.replace(~r/[ ()-]/, "")
    if Regex.match?(~r/^[1-9][0-9]{7,14}$/, number), do: number
  end

  defp digits(_), do: nil
end
