defmodule Sokochat.Release do
  @moduledoc "Database migration entrypoint for the packaged release."
  @app :sokochat

  def migrate do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end
end
