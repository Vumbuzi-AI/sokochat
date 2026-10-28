defmodule Mix.Tasks.Sokochat.Ai.Status do
  use Mix.Task
  @shortdoc "Lists recent AI execution and delivery states without customer content"
  def run(_args) do
    Mix.Task.run("app.start")
    import Ecto.Query

    from(t in Sokochat.Conversations.AiTurn,
      order_by: [desc: t.id],
      limit: 50,
      select: {t.id, t.workspace_id, t.status, t.delivery_status, t.delivery_index}
    )
    |> Sokochat.Repo.all()
    |> Enum.each(fn {id, workspace, state, delivery, part} ->
      Mix.shell().info(
        "turn=#{id} workspace=#{workspace} execution=#{state} delivery=#{delivery} part=#{part}"
      )
    end)
  end
end
