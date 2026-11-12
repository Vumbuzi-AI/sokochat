defmodule Mix.Tasks.Sokochat.Marketplace.Preview do
  use Mix.Task
  @shortdoc "Prepare a local-only marketplace preview with fictional WhatsApp credentials"

  def run(_) do
    if Mix.env() != :dev, do: Mix.raise("This fixture is restricted to local development.")
    Logger.configure(level: :warning)
    Mix.Task.run("app.start")
    alias Sokochat.{Accounts, Catalogs, Marketplace, Meta, Repo, Workspaces}
    alias Sokochat.Catalogs.Item

    owner =
      Accounts.get_user_by_email("shoes@sokochat.local") ||
        Mix.raise("Load the existing Soko Shoes development seed first.")

    line =
      Meta.get_shared_line(owner.id) ||
        elem(
          Meta.upsert_shared_line(owner.id, %{
            phone_number_id: "local-preview-disabled",
            waba_id: "local-preview-disabled",
            access_token: "local-preview-disabled",
            display_phone: "00000000"
          }),
          1
        )

    if line.phone_number_id != "local-preview-disabled",
      do:
        Mix.raise("A real line exists for this owner. Use marketplace.setup with its ID instead.")

    Application.put_env(:sokochat, :marketplace_shared_line_id, line.id)
    {:ok, platform} = Marketplace.ensure_workspace(line)

    shoes =
      Enum.find(Workspaces.list_workspaces(owner.id), &(&1.name == "Soko Shoes")) ||
        Mix.raise("Soko Shoes workspace is missing.")

    {:ok, _} = Marketplace.enroll(shoes)

    seller =
      Accounts.get_user_by_email("accessories@sokochat.local") ||
        case Accounts.register_user(%{
               name: "Soko Accessories",
               email: "accessories@sokochat.local",
               password: "password123"
             }) do
          {:ok, user} -> user
          {:error, _} -> Mix.raise("Unable to create the local accessories seller.")
        end

    if is_nil(seller.confirmed_at),
      do:
        seller
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update!()

    shop =
      Enum.find(Workspaces.list_workspaces(seller.id), &(&1.name == "Soko Accessories")) ||
        case Workspaces.create_workspace(%{name: "Soko Accessories", language: "both"}, seller.id) do
          {:ok, workspace} -> workspace
          {:error, _} -> Mix.raise("Unable to create the local accessories shop.")
        end

    {:ok, _} = Marketplace.enroll(shop)

    {:ok, catalog} =
      Catalogs.upsert_catalog(shop.id, %{name: "Accessories demo", entity_label: "accessory"})

    item =
      Repo.get_by(Item, catalog_id: catalog.id, external_id: "local-demo-cherry-case") ||
        %Item{catalog_id: catalog.id}

    item
    |> Item.changeset(%{
      external_id: "local-demo-cherry-case",
      title: "Cherry iPhone 15 case",
      price: 1500.0,
      currency: "KES",
      image_url: "https://doop.design/a/56AnCFDvTU.webp",
      description: "Fictional demo listing. Compatibility, price and stock are sample data.",
      metadata: %{
        "category" => "Phone accessories",
        "demo_data" => true,
        "variants" => [%{"label" => "iPhone 15", "price" => 1500.0}]
      }
    })
    |> Repo.insert_or_update!()

    Mix.shell().info(
      "Local fixture prepared. WhatsApp credentials are fictional and cannot deliver messages."
    )

    Mix.shell().info(
      "Start Phoenix with MARKETPLACE_SHARED_LINE_ID=#{line.id} AI_BACKEND=pi mix phx.server"
    )

    Mix.shell().info("Marketplace: http://localhost:4000/workspaces/#{platform.id}/playground")
    Mix.shell().info("Shoes inbox: http://localhost:4000/workspaces/#{shoes.id}/inbox")
    Mix.shell().info("Accessories inbox: http://localhost:4000/workspaces/#{shop.id}/inbox")
  end
end
