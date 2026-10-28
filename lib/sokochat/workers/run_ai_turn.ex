defmodule Sokochat.Workers.RunAiTurn do
  use Oban.Worker,
    queue: :intelligence,
    max_attempts: 20,
    unique: [
      keys: [:turn_id],
      period: :infinity,
      states: :incomplete
    ]

  @impl true
  def timeout(_job), do: 45_000

  alias Sokochat.Repo
  alias Sokochat.Conversations.{AiTurn, Conversation, DurableTurns}
  alias Sokochat.AI.PiClient

  @impl true
  def perform(%Oban.Job{args: %{"turn_id" => id}}) do
    case Repo.get(AiTurn, id) do
      nil -> :ok
      %AiTurn{status: status} when status != "queued" -> :ok
      turn -> run(turn)
    end
  end

  defp run(turn) do
    cond do
      DateTime.diff(DateTime.utc_now(), turn.inserted_at) > 900 ->
        DurableTurns.fail(
          turn.id,
          "The assistant could not finish this request. Please try again."
        )

      DurableTurns.earlier_pending?(turn) ->
        {:snooze, 2}

      true ->
        conversation = Repo.get!(Conversation, turn.conversation_id)

        if conversation.policy_strikes >= 2 do
          DurableTurns.complete(turn.id, %{
            reply: "I can only help with this shop. Ask about a product when you're ready.",
            cta: nil,
            tokens: 0,
            policy: "ok"
          })
        else
          with {:ok, payload} <- DurableTurns.payload(turn),
               {:ok, result} <- PiClient.exchange(payload) do
            case result do
              %{"status" => "pending"} ->
                {:snooze, 2}

              %{"status" => "done"} ->
                case PiClient.decode_answer(result) do
                  {:ok, reply} ->
                    DurableTurns.complete(turn.id, reply)

                  {:error, _} ->
                    DurableTurns.fail(
                      turn.id,
                      "The assistant returned an invalid reply. Please try again."
                    )
                end

              %{"status" => "failed"} ->
                DurableTurns.fail(
                  turn.id,
                  "The assistant could not finish this request. Please try again."
                )

              _ ->
                DurableTurns.fail(
                  turn.id,
                  "The intelligence service returned an invalid turn state."
                )
            end
          else
            # Leave the persisted turn queued on transport errors. Oban retries
            # the same immutable request; the browser need not remain connected.
            {:error, _} -> {:snooze, 5}
          end
        end
    end
  end
end
