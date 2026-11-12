defmodule Mix.Tasks.Sokochat.Marketplace.Setup do
  use Mix.Task
  import Ecto.Query

  @shortdoc "Provision a platform workspace and enroll existing manual shops on the configured line"

  def run(args) do
    Mix.Task.run("app.start")
    alias Sokochat.{Marketplace, Repo}
    alias Sokochat.Workspaces.Workspace

    line =
      Marketplace.configured_line() ||
        Mix.raise("Set MARKETPLACE_SHARED_LINE_ID to the Sokochat line's database ID first.")

    {:ok, workspace} = Marketplace.ensure_workspace(line)

    if "--enroll-existing" in args do
      shops =
        Repo.all(
          from w in Workspace,
            where: not w.marketplace and w.data_source == "manual" and is_nil(w.shared_line_id)
        )

      Enum.each(shops, fn shop ->
        case Marketplace.enroll(shop) do
          {:ok, _} ->
            :ok

          {:error, _} ->
            Mix.raise("Unable to enroll workspace #{shop.id}; resolve it before continuing.")
        end
      end)

      Mix.shell().info(
        "Enrolled #{length(shops)} manual shops. Existing line memberships were preserved."
      )
    end

    Mix.shell().info(
      "Marketplace workspace #{workspace.id}. Owner-only preview: /workspaces/#{workspace.id}/playground"
    )
  end
end
