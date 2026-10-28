defmodule Sokochat.Workers.ReconcileAiTurns do
  @moduledoc "Repairs missing/exhausted job ownership using persisted turn state."
  use Oban.Worker, queue: :intelligence, max_attempts: 3
  import Ecto.Query
  alias Sokochat.Repo
  alias Sokochat.Conversations.AiTurn

  @impl true
  def perform(_job) do
    stale_before = DateTime.add(DateTime.utc_now(), -120, :second)
    workers = ["Sokochat.Workers.RunAiTurn", "Sokochat.Workers.DeliverAiReply"]
    # These workers have 45s/20s hard timeouts. Repair only their orphaned
    # executions, rather than changing recovery semantics for unrelated queues.
    from(j in Oban.Job,
      where: j.worker in ^workers and j.state == "executing" and j.attempted_at < ^stale_before,
      select: j.id
    )
    |> Repo.all()
    |> Enum.each(&Oban.cancel_job/1)

    from(t in AiTurn, where: t.status == "queued", order_by: [asc: t.id], limit: 500)
    |> Repo.all()
    |> Enum.each(fn turn ->
      %{turn_id: turn.id} |> Sokochat.Workers.RunAiTurn.new() |> Oban.insert()
    end)

    from(t in AiTurn,
      where: t.status == "completed" and t.delivery_status in ["pending", "sending"],
      order_by: [asc: t.id],
      limit: 500
    )
    |> Repo.all()
    |> Enum.each(fn turn ->
      %{turn_id: turn.id} |> Sokochat.Workers.DeliverAiReply.new() |> Oban.insert()
    end)

    :ok
  end
end
