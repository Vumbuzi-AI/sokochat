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

  @doc "Enroll existing manual shops on the configured marketplace line, without starting another server."
  def setup_marketplace do
    import Ecto.Query
    alias Sokochat.{Marketplace, Repo}
    alias Sokochat.Workspaces.Workspace

    Application.ensure_loaded(@app)
    endpoint = Application.fetch_env!(@app, SokochatWeb.Endpoint)
    Application.put_env(@app, SokochatWeb.Endpoint, Keyword.put(endpoint, :server, false))
    oban = Application.fetch_env!(@app, Oban)
    Application.put_env(@app, Oban, Keyword.merge(oban, queues: false, plugins: false))
    {:ok, _} = Application.ensure_all_started(@app)

    line = Marketplace.configured_line() || raise("Set MARKETPLACE_SHARED_LINE_ID first")

    {:ok, result} =
      Repo.transaction(fn ->
        {:ok, platform} = Marketplace.ensure_workspace(line)

        shops =
          Repo.all(
            from w in Workspace,
              where: not w.marketplace and w.data_source == "manual" and is_nil(w.shared_line_id)
          )

        Enum.each(shops, fn shop ->
          case Marketplace.enroll(shop) do
            {:ok, _} -> :ok
            {:error, _} -> Repo.rollback("Unable to enroll workspace #{shop.id}")
          end
        end)

        %{marketplace_workspace_id: platform.id, enrolled_shops: length(shops), line_id: line.id}
      end)

    IO.inspect(result, label: "Marketplace setup")
  end
end
