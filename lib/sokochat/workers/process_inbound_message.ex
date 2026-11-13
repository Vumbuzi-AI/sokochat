defmodule Sokochat.Workers.ProcessInboundMessage do
  @moduledoc """
  Processes a single inbound WhatsApp message: runs it through the shared
  conversation `Dispatcher` and sends the assistant reply back through Meta.

  Jobs from a dedicated workspace webhook carry `workspace_id`. Jobs from the
  shared-line webhook carry `shared_line_id` and are routed to a shop first.

  Duplicate protection is handled by Oban uniqueness keyed on the WhatsApp
  message id, so Meta's at-least-once webhook delivery never double-processes.
  """

  use Oban.Worker,
    queue: :meta_send,
    max_attempts: 3,
    unique: [keys: [:whatsapp_message_id], period: 60 * 60 * 24]

  alias Sokochat.Conversations.Dispatcher
  alias Sokochat.Meta
  alias Sokochat.Meta.Sender
  alias Sokochat.Meta.SharedLine
  alias Sokochat.Meta.ShopRouter
  alias Sokochat.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"shared_line_id" => shared_line_id} = args}) do
    phone_number = args["phone_number"]
    message_text = args["message_text"] || ""
    reply_id = args["reply_id"]

    case Repo.get(SharedLine, shared_line_id) do
      nil ->
        Logger.warning("No shared line #{shared_line_id}; dropping inbound message")
        :ok

      shared_line ->
        case ShopRouter.route(
               shared_line,
               phone_number,
               message_text,
               reply_id,
               args["whatsapp_message_id"]
             ) do
          {:dispatch, shop, cleaned_text, opts} ->
            maybe_send_switch_notice(shared_line, phone_number, opts)
            dispatch_and_reply(shop.id, phone_number, cleaned_text, args, opts)

          {:picker, intro, cta} ->
            send_picker(shared_line, phone_number, intro, cta)
        end
    end
  end

  def perform(%Oban.Job{args: %{"workspace_id" => workspace_id} = args}) do
    phone_number = args["phone_number"]
    message_text = args["message_text"]

    case Meta.connection_for_send(workspace_id) do
      nil ->
        Logger.warning(
          "No Meta connection for workspace #{workspace_id}; dropping inbound message"
        )

        :ok

      _connection ->
        dispatch_and_reply(workspace_id, phone_number, message_text, args)
    end
  end

  defp dispatch_and_reply(workspace_id, phone_number, message_text, args, opts \\ []) do
    connection = Meta.connection_for_send(workspace_id)

    if is_nil(connection) do
      Logger.warning(
        "No Meta credentials for workspace #{workspace_id}; dropping inbound message"
      )

      :ok
    else
      show_typing(connection, args["whatsapp_message_id"])

      if Sokochat.AI.Intelligence.agentic?() do
        case Dispatcher.dispatch(workspace_id, phone_number, message_text, :whatsapp,
               wait: false,
               source_key: "whatsapp:#{args["whatsapp_message_id"]}",
               marketplace_reply: Keyword.get(opts, :marketplace_reply),
               preferred_shop: Keyword.get(opts, :preferred_shop)
             ) do
          {:ok, _turn} -> :ok
          {:error, reason} -> {:error, reason}
        end
      else
        with {:ok, assistant_message} <-
               Dispatcher.dispatch(workspace_id, phone_number, message_text, :whatsapp),
             {:ok, _id} <-
               Sender.send_reply(
                 connection,
                 phone_number,
                 assistant_message.content,
                 assistant_message.cta
               ) do
          :ok
        else
          {:error, reason} ->
            _ = Meta.mark_error(connection, reason)
            Logger.error("Failed to handle inbound WhatsApp message: #{inspect(reason)}")
            {:error, reason}
        end
      end
    end
  end

  defp show_typing(_connection, id) when id in [nil, ""], do: :ok

  defp show_typing(connection, message_id) do
    case Sender.show_typing(connection, message_id) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("WhatsApp typing indicator failed: #{inspect(reason)}")
        :ok
    end
  end

  # Send the switch notice through the shared line before the shop reply.
  defp maybe_send_switch_notice(shared_line, phone_number, opts) do
    case Keyword.get(opts, :switch_notice) do
      notice when is_binary(notice) and notice != "" ->
        case Sender.send_reply(shared_line, phone_number, notice, nil) do
          {:ok, _} -> :ok
          {:error, reason} -> Logger.warning("Shop switch notice failed: #{inspect(reason)}")
        end

      _ ->
        :ok
    end
  end

  defp send_picker(shared_line, phone_number, intro, cta) do
    body =
      case intro do
        text when is_binary(text) and text != "" -> text
        _ -> get_in(cta, ["payload", "body"]) || "Which shop would you like to talk to?"
      end

    case Sender.send_reply(shared_line, phone_number, body, cta) do
      {:ok, _id} ->
        :ok

      {:error, reason} ->
        _ = Meta.mark_error(shared_line, reason)
        Logger.error("Failed to send shop picker: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
