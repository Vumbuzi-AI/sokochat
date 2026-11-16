defmodule Sokochat.PhoneNumberTest do
  use ExUnit.Case, async: true
  alias Sokochat.PhoneNumber

  test "groups Kenyan and UAE sender IDs without changing the WhatsApp recipient" do
    assert PhoneNumber.format("254745123456") == "+254 745 123 456"
    assert PhoneNumber.format("971582301251") == "+971 58 230 1251"
    assert PhoneNumber.whatsapp_url("+254 745 123 456") == "https://wa.me/254745123456"
    assert PhoneNumber.whatsapp_url("+971 58 230 1251") == "https://wa.me/971582301251"
  end

  test "preserves unfamiliar international numbers and never guesses a local country" do
    assert PhoneNumber.format("447911123456") == "+447911123456"
    assert PhoneNumber.whatsapp_url("447911123456") == "https://wa.me/447911123456"
    assert PhoneNumber.format("0745123456") == "0745123456"
    assert PhoneNumber.whatsapp_url("0745123456") == nil
  end

  test "malformed and missing numbers cannot become click-to-chat links" do
    for number <- [nil, "", "preview_buyer", "25474507jnj", "12", "+254745123456?text=hello"] do
      assert PhoneNumber.whatsapp_url(number) == nil
    end

    assert PhoneNumber.format(nil) == "Number unavailable"
    assert PhoneNumber.format("25474507jnj") == "25474507jnj"
  end
end
