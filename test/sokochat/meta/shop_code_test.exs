defmodule Sokochat.Meta.ShopCodeTest do
  use ExUnit.Case, async: true

  alias Sokochat.Meta.ShopCode

  describe "extract/1" do
    test "finds a token in the middle and strips it" do
      assert {:ok, "brookside", "Hi from Brookside Kenya please"} =
               ShopCode.extract("Hi from Brookside Kenya [shop:brookside] please")
    end

    test "is case-insensitive and normalizes the code" do
      assert {:ok, "royco", "Hello there"} =
               ShopCode.extract("Hello there [SHOP:Royco]")
    end

    test "empty remainder becomes Hello" do
      assert {:ok, "brookside", "Hello"} = ShopCode.extract("[shop:brookside]")
    end

    test "returns :none when there is no token" do
      assert ShopCode.extract("Just saying hello") == :none
    end

    test "returns :none for junk codes" do
      assert ShopCode.extract("Hello [shop:Not Valid!]") == :none
      assert ShopCode.extract("Hello [shop:]") == :none
    end
  end

  describe "from_reply_id/1" do
    test "parses shop reply ids" do
      assert ShopCode.from_reply_id("shop:brookside") == {:ok, "brookside"}
      assert ShopCode.from_reply_id("SHOP:Royco") == {:ok, "royco"}
    end

    test "ignores unrelated ids" do
      assert ShopCode.from_reply_id("row_0") == :none
      assert ShopCode.from_reply_id("btn_1") == :none
      assert ShopCode.from_reply_id(nil) == :none
    end
  end
end
