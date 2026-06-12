defmodule Sokochat.Conversations.ProductCTATest do
  use ExUnit.Case, async: true

  alias Sokochat.Conversations.ProductCTA

  test "does not attach a product CTA for a generic reply when multiple products exist" do
    endpoint_data = %{
      "products" => [
        %{
          "name" => "Classic Hoodie",
          "price" => 39.99,
          "currency" => "USD",
          "image_url" => "https://images.unsplash.com/classic-hoodie.jpg",
          "url" => "https://shop.example.com/products/classic-hoodie"
        },
        %{
          "name" => "Wireless Earbuds",
          "price" => 79.50,
          "currency" => "USD",
          "image_url" => "https://images.unsplash.com/wireless-earbuds.jpg",
          "url" => "https://shop.example.com/products/wireless-earbuds"
        }
      ]
    }

    assert ProductCTA.attach(
             "Hey! How can I help you today? Are you looking for a specific product?",
             "Hey",
             endpoint_data,
             nil
           ) == nil
  end

  test "attaches a matching product CTA when the reply mentions the product" do
    endpoint_data = %{
      "products" => [
        %{
          "name" => "Classic Hoodie",
          "price" => 39.99,
          "currency" => "USD",
          "image_url" => "https://images.unsplash.com/classic-hoodie.jpg",
          "url" => "https://shop.example.com/products/classic-hoodie"
        },
        %{
          "name" => "Wireless Earbuds",
          "price" => 79.50,
          "currency" => "USD",
          "image_url" => "https://images.unsplash.com/wireless-earbuds.jpg",
          "url" => "https://shop.example.com/products/wireless-earbuds"
        }
      ]
    }

    assert ProductCTA.attach(
             "The Classic Hoodie is available in stock.",
             "Show me the hoodie",
             endpoint_data,
             nil
           ) == %{
             "type" => "website",
             "payload" => %{
               "body" => "USD 39.99",
               "image_url" => "https://images.unsplash.com/classic-hoodie.jpg",
               "title" => "Classic Hoodie",
               "url" => "https://shop.example.com/products/classic-hoodie"
             }
           }
  end

  test "does not attach a single product CTA when the reply mentions multiple products" do
    endpoint_data = %{
      "products" => [
        %{
          "name" => "Classic Hoodie",
          "price" => 39.99,
          "currency" => "USD",
          "image_url" => "https://images.unsplash.com/classic-hoodie.jpg",
          "url" => "https://shop.example.com/products/classic-hoodie"
        },
        %{
          "name" => "Wireless Earbuds",
          "price" => 79.50,
          "currency" => "USD",
          "image_url" => "https://images.unsplash.com/wireless-earbuds.jpg",
          "url" => "https://shop.example.com/products/wireless-earbuds"
        },
        %{
          "name" => "Running Shoes",
          "price" => 96.75,
          "currency" => "USD",
          "image_url" => "https://images.unsplash.com/running-shoes.jpg",
          "url" => "https://shop.example.com/products/running-shoes"
        }
      ]
    }

    assert ProductCTA.attach(
             """
             We offer items like:
             - Classic Hoodie - $39.99
             - Wireless Earbuds - $79.50

             Running Shoes are currently out of stock. What would you like to see?
             """,
             "show me what you have",
             endpoint_data,
             nil
           ) == nil
  end
end
