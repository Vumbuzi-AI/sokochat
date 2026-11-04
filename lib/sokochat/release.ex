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

  def seed_shoes do
    password = System.fetch_env!("SEED_SHOES_PASSWORD")

    if String.length(password) < 16,
      do: raise("Set SEED_SHOES_PASSWORD to at least 16 characters")

    Application.ensure_loaded(@app)

    endpoint = Application.fetch_env!(@app, SokochatWeb.Endpoint)
    Application.put_env(@app, SokochatWeb.Endpoint, Keyword.put(endpoint, :server, false))
    oban = Application.fetch_env!(@app, Oban)
    Application.put_env(@app, Oban, Keyword.merge(oban, queues: false, plugins: false))
    {:ok, _} = Application.ensure_all_started(@app)
    Code.eval_file(Application.app_dir(@app, "priv/repo/seeds_shoes.exs"))
  end
end
