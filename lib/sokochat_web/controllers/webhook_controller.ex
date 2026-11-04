defmodule SokochatWeb.WebhookController do
  @moduledoc """
  WhatsApp Cloud API webhook endpoints. Meta calls these as plain HTTP requests,
  so they live on the `:api` pipeline (no session / CSRF).

  Two URL shapes are supported:

  - `/webhooks/whatsapp/:slug` — dedicated per-workspace number
  - `/webhooks/whatsapp` — account shared line used by multiple shops
  """

  use SokochatWeb, :controller

  alias Sokochat.Meta
  alias Sokochat.Workers.ProcessInboundMessage

  require Logger

  plug SokochatWeb.VerifyMetaSignature when action in [:handle_message, :handle_shared_message]

  @doc """
  GET handler for a dedicated workspace webhook. Echoes `hub.challenge` when the
  verify token matches the stored connection.
  """
  def handle_verification(conn, %{"slug" => slug} = params) do
    mode = params["hub.mode"]
    token = params["hub.verify_token"]
    challenge = params["hub.challenge"]

    with "subscribe" <- mode,
         %Meta.Connection{} = connection <- Meta.get_connection_by_workspace_slug(slug),
         true <- secure_compare(connection.verify_token, token) do
      _ = Meta.mark_verified(connection)

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, challenge || "")
    else
      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(403, "Forbidden")
    end
  end

  @doc """
  GET handler for the shared-line webhook. Verifies against the shared line's
  verify token (looked up by the token Meta sends).
  """
  def handle_shared_verification(conn, params) do
    mode = params["hub.mode"]
    token = params["hub.verify_token"]
    challenge = params["hub.challenge"]

    with "subscribe" <- mode,
         %Meta.SharedLine{} = shared_line <- Meta.get_shared_line_by_verify_token(token),
         true <- secure_compare(shared_line.verify_token, token) do
      _ = Meta.mark_verified(shared_line)

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, challenge || "")
    else
      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(403, "Forbidden")
    end
  end

  @doc """
  POST handler for dedicated workspace inbound events. Returns 200 immediately
  and enqueues user messages for background processing; status callbacks are ignored.
  """
  def handle_message(conn, %{"slug" => slug} = params) do
    case Meta.get_connection_by_workspace_slug(slug) do
      %Meta.Connection{workspace: workspace} ->
        params
        |> extract_inbound_messages()
        |> Enum.each(&enqueue_workspace(&1, workspace.id))

      nil ->
        Logger.warning("Inbound webhook for unknown workspace slug: #{slug}")
    end

    send_resp(conn, 200, "ok")
  end

  @doc """
  POST handler for the shared-line webhook. Resolves the shared line from the
  payload's phone_number_id and enqueues shop routing.
  """
  def handle_shared_message(conn, params) do
    phone_number_id = extract_phone_number_id(params)

    case Meta.resolve_shared_line_for_inbound(phone_number_id) do
      %Meta.SharedLine{} = shared_line ->
        params
        |> extract_inbound_messages()
        |> Enum.each(&enqueue_shared(&1, shared_line.id))

      nil ->
        Logger.warning(
          "Inbound shared webhook with no matching shared line (phone_number_id=#{inspect(phone_number_id)})"
        )
    end

    send_resp(conn, 200, "ok")
  end

  defp enqueue_workspace(%{from: from, text: text, id: id} = inbound, workspace_id) do
    %{
      "workspace_id" => workspace_id,
      "phone_number" => from,
      "message_text" => text,
      "whatsapp_message_id" => id,
      "reply_id" => inbound[:reply_id]
    }
    |> ProcessInboundMessage.new()
    |> Oban.insert()
  end

  defp enqueue_shared(%{from: from, text: text, id: id} = inbound, shared_line_id) do
    %{
      "shared_line_id" => shared_line_id,
      "phone_number" => from,
      "message_text" => text,
      "whatsapp_message_id" => id,
      "reply_id" => inbound[:reply_id]
    }
    |> ProcessInboundMessage.new()
    |> Oban.insert()
  end

  # Defensively walk Meta's payload, which can carry multiple entries/changes and
  # several event shapes (messages, statuses, errors). We only keep real inbound
  # text / interactive messages.
  defp extract_inbound_messages(%{"entry" => entries}) when is_list(entries) do
    for entry <- entries,
        change <- List.wrap(entry["changes"]),
        message <- List.wrap(get_in(change, ["value", "messages"])),
        inbound = normalize_message(message),
        not is_nil(inbound) do
      inbound
    end
  end

  defp extract_inbound_messages(_params), do: []

  defp extract_phone_number_id(%{"entry" => entries}) when is_list(entries) do
    entries
    |> Enum.find_value(fn entry ->
      entry
      |> Map.get("changes", [])
      |> List.wrap()
      |> Enum.find_value(fn change ->
        get_in(change, ["value", "metadata", "phone_number_id"])
      end)
    end)
  end

  defp extract_phone_number_id(_), do: nil

  defp normalize_message(%{"from" => from, "id" => id} = message) do
    case message_content(message) do
      nil ->
        nil

      {nil, nil} ->
        nil

      {text, reply_id} ->
        text = text || ""

        if String.trim(text) == "" and is_nil(reply_id) do
          nil
        else
          %{from: from, id: id, text: text, reply_id: reply_id}
        end
    end
  end

  defp normalize_message(_message), do: nil

  defp message_content(%{"type" => "text", "text" => %{"body" => body}}) do
    {body, nil}
  end

  defp message_content(%{"type" => "interactive", "interactive" => interactive}) do
    cond do
      is_map(interactive["button_reply"]) ->
        reply = interactive["button_reply"]
        {reply["title"], reply["id"]}

      is_map(interactive["list_reply"]) ->
        reply = interactive["list_reply"]
        {reply["title"], reply["id"]}

      true ->
        nil
    end
  end

  defp message_content(%{"type" => "button", "button" => button}) when is_map(button) do
    {button["text"], button["payload"]}
  end

  defp message_content(_message), do: nil

  defp secure_compare(nil, _), do: false
  defp secure_compare(_, nil), do: false
  defp secure_compare(left, right), do: Plug.Crypto.secure_compare(left, right)
end
