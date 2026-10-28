defmodule SokochatWeb.WebhookBodyReader do
  @moduledoc "Preserves exact webhook bytes for signature verification before job admission."
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {state, bytes, conn} when state in [:ok, :more] ->
        conn =
          if conn.method == "POST" and String.starts_with?(conn.request_path, "/webhooks/") do
            chunks = [bytes | Map.get(conn.private, :webhook_chunks, [])]
            conn = Plug.Conn.put_private(conn, :webhook_chunks, chunks)

            if state == :ok,
              do:
                Plug.Conn.put_private(
                  conn,
                  :webhook_raw_body,
                  chunks |> Enum.reverse() |> IO.iodata_to_binary()
                ),
              else: conn
          else
            conn
          end

        {state, bytes, conn}

      error ->
        error
    end
  end
end
