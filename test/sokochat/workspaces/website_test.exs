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
end
