defmodule Mix.Tasks.Sokochat.Ai.ResolveDelivery do
  use Mix.Task
  @shortdoc "Resolves one manually reviewed ambiguous delivery part"
  def run([id, decision, "--reviewed"]) when decision in ["sent", "retry"] do
    Mix.Task.run("app.start")
    import Ecto.Query
    {id, ""} = Integer.parse(id)

    {:ok, _} =
      Sokochat.Repo.transaction(fn ->
        turn =
          Sokochat.Repo.one!(
            from t in Sokochat.Conversations.AiTurn, where: t.id == ^id, lock: "FOR UPDATE"
          )

        unless turn.delivery_status == "uncertain",
          do: Mix.raise("Only uncertain deliveries can be reviewed")

        index = if decision == "sent", do: turn.delivery_index + 1, else: turn.delivery_index

        note =
          "Delivery part #{turn.delivery_index} manually reviewed as #{decision} at #{DateTime.utc_now()}"

        turn
        |> Ecto.Changeset.change(
          delivery_status: "pending",
          delivery_index: index,
          last_error: note
        )
        |> Sokochat.Repo.update!()

        %{turn_id: id} |> Sokochat.Workers.DeliverAiReply.new() |> Oban.insert!()
      end)

    Mix.shell().info("Review saved. Remaining delivery work has been queued.")
  end

  def run(_),
    do:
      Mix.raise(
        "Usage: mix sokochat.ai.resolve_delivery TURN_ID sent|retry --reviewed. Inspect Meta delivery first; retry can duplicate a message already accepted by Meta."
      )
end
