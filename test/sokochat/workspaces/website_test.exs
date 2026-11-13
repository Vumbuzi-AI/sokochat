defmodule Sokochat.Workspaces.WebsiteTest do
  use ExUnit.Case, async: false

  alias Sokochat.Workspaces.Website

  setup do
    on_exit(fn -> Application.delete_env(:sokochat, :website_req_options) end)
    :ok
  end

  test "refuses a private address" do
    assert {:error, "That link is not a public website."} =
             Website.brief("http://127.0.0.1/about")

    assert {:error, "That link is not a public website."} = Website.brief("http://192.168.1.8")
  end

  test "refuses a link that is not http" do
    assert {:error, "Use a link starting with https://"} =
             Website.brief("ftp://shop.example/about")
  end

  test "reads the title and description from a public page" do
    Req.Test.stub(WebsiteStub, fn conn ->
      Req.Test.html(conn, """
      <html>
        <head>
          <title>Soko Shoes</title>
          <meta name="description" content="Nairobi sneaker shop. Same-day delivery.">
        </head>
        <body><p>EU sizes from 38 to 45.</p><script>secret()</script></body>
      </html>
      """)
    end)

    Process.put(:website_req_options, plug: {Req.Test, WebsiteStub})

    assert {:ok, brief} = Website.brief("https://example.com/shop")
    assert brief =~ "Business: Soko Shoes"
    assert brief =~ "Nairobi sneaker shop. Same-day delivery."
    assert brief =~ "EU sizes from 38 to 45."
    refute brief =~ "secret"
  end

  test "extracts structured address and hours without inventing delivery fees" do
    Req.Test.stub(WebsiteProfileStub, fn conn ->
      Req.Test.html(conn, """
      <html><head><title>A shop</title><script type="application/ld+json">
      {"@type":"Store","address":{"streetAddress":"Shop 12, Moi Avenue","addressLocality":"Nairobi"},"openingHoursSpecification":[{"dayOfWeek":["https://schema.org/Monday"],"opens":"09:00","closes":"18:00"}]}
      </script></head><body><a href="https://maps.google.com/?q=Moi+Avenue">Map</a></body></html>
      """)
    end)

    Process.put(:website_req_options, plug: {Req.Test, WebsiteProfileStub})
    assert {:ok, details} = Website.profile("https://example.com")
    assert details["location"] == "Shop 12, Moi Avenue, Nairobi"
    assert details["opening_hours"] == "Monday 09:00–18:00"
    assert details["map_url"] == "https://maps.google.com/?q=Moi+Avenue"
    refute Map.has_key?(details, "delivery_rates")
    refute Map.has_key?(details, "pickup_enabled")
  end
end
