defmodule SokochatWeb.VerifyMetaSignature do
  @moduledoc "Authenticates Meta POST payloads against their exact raw body bytes."
  import Plug.Conn
  def init(opts), do: opts

  def call(conn, _opts) do
    config = Application.get_env(:sokochat, :meta, [])
    secret = Keyword.get(config, :app_secret)
    required = Keyword.get(config, :require_signature, false)

    cond do
      is_binary(secret) and secret != "" -> verify(conn, secret)
      required -> conn |> send_resp(503, "Webhook authentication is not configured") |> halt()
      true -> conn
    end
  end

  defp verify(conn, secret) do
    with ["sha256=" <> signature] <- get_req_header(conn, "x-hub-signature-256"),
         {:ok, digest} <- Base.decode16(signature, case: :mixed),
         true <- byte_size(digest) == 32,
         raw when is_binary(raw) <- conn.private[:webhook_raw_body],
         expected <- :crypto.mac(:hmac, :sha256, secret, raw),
         true <- Plug.Crypto.secure_compare(digest, expected) do
      conn
    else
      _ -> conn |> send_resp(403, "Invalid webhook signature") |> halt()
    end
  end
end
