defmodule SokochatWeb.VerifyMetaSignatureTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  alias SokochatWeb.VerifyMetaSignature

  setup do
    previous = Application.get_env(:sokochat, :meta, [])
    Application.put_env(:sokochat, :meta, app_secret: "test-secret", require_signature: true)
    on_exit(fn -> Application.put_env(:sokochat, :meta, previous) end)
    :ok
  end

  test "authenticates exact raw bytes, not parsed or re-encoded JSON" do
    raw = "{ \"entry\": [] }"
    signature = :crypto.mac(:hmac, :sha256, "test-secret", raw) |> Base.encode16(case: :lower)

    conn =
      Plug.Test.conn(:post, "/webhooks/shop", raw)
      |> put_private(:webhook_raw_body, raw)
      |> put_req_header("x-hub-signature-256", "sha256=" <> signature)

    refute VerifyMetaSignature.call(conn, []).halted
    tampered = put_private(conn, :webhook_raw_body, "{\"entry\":[]}")
    assert VerifyMetaSignature.call(tampered, []).status == 403
  end

  test "rejects unsigned webhook payloads" do
    conn =
      Plug.Test.conn(:post, "/webhooks/shop", "{}")
      |> put_private(:webhook_raw_body, "{}")

    assert VerifyMetaSignature.call(conn, []).status == 403
  end

  test "production fails closed when its app secret is unavailable" do
    Application.put_env(:sokochat, :meta, require_signature: true)

    assert VerifyMetaSignature.call(Plug.Test.conn(:post, "/webhooks/shop", "{}"), []).status ==
             503
  end
end
