defmodule Sokochat.Workers.DeliverAiReply do
  @moduledoc "Persisted, per-part delivery. Ambiguous sends stop for review rather than resending."
  use Oban.Worker,
    queue: :meta_send,
    max_attempts: 5,
    unique: [
      keys: [:turn_id],
      period: :infinity,
      states: :incomplete
    ]

  @impl true
  def timeout(_job), do: 20_000

  import Ecto.Query
  alias Sokochat.{Repo, Meta}
  alias Sokochat.Conversations.{AiTurn, Conversation, Message}
  alias Sokochat.Meta.Sender

  @impl true
  def perform(%Oban.Job{args: %{"turn_id" => id}}) do
    case claim(id) do
      {:ok, :done} ->
        :ok

      {:ok, :wait} ->
        {:snooze, 60}

      {:ok, {connection, phone, part, index}} ->
        case Sender.send_outbox_message(connection, phone, part) do
          {:ok, message_id} when is_binary(message_id) and message_id != "" ->
            Repo.transaction(fn ->
              turn = Repo.one!(from t in AiTurn, where: t.id == ^id, lock: "FOR UPDATE")

              if turn.delivery_status == "sending" and turn.delivery_index == index do
                turn
                |> Ecto.Changeset.change(
                  delivery_status: "pending",
                  delivery_index: index + 1,
                  provider_message_ids: turn.provider_message_ids ++ [message_id]
                )
                |> Repo.update!()
              end
            end)

            {:snooze, 1}

          _ ->
            uncertain(id)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp claim(id) do
    Repo.transaction(fn ->
      turn = Repo.one(from t in AiTurn, where: t.id == ^id, lock: "FOR UPDATE")

      cond do
        is_nil(turn) or turn.delivery_status in ["none", "sent", "uncertain"] ->
          :done

        turn.delivery_status == "sending" ->
          # A previous worker may have reached Meta before dying. No safe automatic retry.
          turn
          |> Ecto.Changeset.change(
            delivery_status: "uncertain",
            last_error: "WhatsApp delivery needs review; the previous send may have reached Meta."
          )
          |> Repo.update!()

          :done

        DateTime.diff(DateTime.utc_now(), turn.inserted_at) > 82_800 ->
          turn
          |> Ecto.Changeset.change(
            delivery_status: "uncertain",
            last_error:
              "Delivery stopped before the customer-service window expires. Review Meta before taking further action."
          )
          |> Repo.update!()

          :done

        true ->
          connection = Meta.get_connection(turn.workspace_id)
          conversation = Repo.get(Conversation, turn.conversation_id)
          assistant = Repo.get(Message, turn.assistant_message_id)

          cond do
            is_nil(connection) ->
              :wait

            is_nil(conversation) or is_nil(assistant) ->
              :done

            true ->
              parts = Sender.build_messages(assistant.cta, assistant.content)

              case Enum.at(parts, turn.delivery_index) do
                nil ->
                  turn |> Ecto.Changeset.change(delivery_status: "sent") |> Repo.update!()
                  :done

                part ->
                  turn |> Ecto.Changeset.change(delivery_status: "sending") |> Repo.update!()
                  {connection, conversation.phone_number, part, turn.delivery_index}
              end
          end
      end
    end)
  end

  defp uncertain(id) do
    from(t in AiTurn, where: t.id == ^id and t.delivery_status == "sending")
    |> Repo.update_all(
      set: [
        delivery_status: "uncertain",
        last_error: "WhatsApp delivery needs review; this send may have reached Meta."
      ]
    )

    :ok
  end
end
