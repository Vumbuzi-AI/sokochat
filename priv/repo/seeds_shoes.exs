# Standalone, repeatable shoe-store demo: mix run priv/repo/seeds_shoes.exs
# Also loaded by seeds.exs. Prices, sizes, and stock below are fictional fixtures.
alias Sokochat.Accounts
alias Sokochat.Accounts.User
alias Sokochat.Catalogs
alias Sokochat.Catalogs.Item
alias Sokochat.CTARules
alias Sokochat.Repo
alias Sokochat.Workspaces
alias Sokochat.Workspaces.Workspace

email = System.get_env("SEED_SHOES_EMAIL", "shoes@sokochat.local")
password = System.get_env("SEED_SHOES_PASSWORD", "password123")
image_base = "https://pub-0a313ba028f9423cba4b9803d081b5db.r2.dev/products/sokochat-shoes"

{:ok, workspace} =
  Repo.transaction(fn ->
    user =
      Accounts.get_user_by_email(email) ||
        case Accounts.register_user(%{name: "Soko Shoes Owner", email: email, password: password}) do
          {:ok, user} -> user
          {:error, changeset} -> Repo.rollback(changeset)
        end

    user = user |> User.password_changeset(%{password: password}) |> Repo.update!()
    if is_nil(user.confirmed_at), do: user |> User.confirm_changeset() |> Repo.update!()

    attrs = %{
      name: "Soko Shoes",
      language: "en",
      data_source: "manual",
      company_name: "Soko Shoes",
      industry: "Footwear",
      about:
        "A fictional shoe store for testing SokoChat. All prices, sizes, and stock are demo data.",
      ai_instructions: """
      Help shoppers browse Adidas Spezial, Nike Shox, and Onitsuka Tigers.
      These are fictional demo listings. Use only the supplied variant prices and sizes.
      When asked for a specific shoe, keep the reply focused on that shoe and show its
      catalog card with the supplied image URL. Do not print image URLs in the reply.
      Do not claim a particular colourway, authenticity, delivery policy, payment method,
      contact number, or checkout link: these have not been provided.
      For broad browsing, offer the three shoe names as reply buttons.
      """
    }

    workspace =
      case Repo.get_by(Workspace, account_id: user.id, slug: "soko-shoes") do
        nil ->
          {:ok, workspace} = Workspaces.create_workspace(attrs, user.id)
          workspace

        workspace ->
          {:ok, workspace} = Workspaces.update_workspace(workspace, attrs)
          workspace
      end

    {:ok, catalog} =
      Catalogs.upsert_catalog(workspace.id, %{
        name: "Soko Shoes demo catalog",
        entity_label: "shoe",
        categories: ["Sneakers"],
        context_notes:
          "Fictional demo prices and stock. Sizes use EU sizing. Only the three named products are seeded; adding files to R2 does not create products automatically."
      })

    shoes = [
      {"adidas-spezial", "Adidas Spezial", 6500, [38, 39, 40, 41, 42]},
      {"nike-shox", "Nike Shox", 8500, [40, 41, 42, 43, 44]},
      {"onitsuka-tigers", "Onitsuka Tigers", 7500, [37, 38, 39, 40, 41]}
    ]

    Enum.with_index(shoes, 1)
    |> Enum.each(fn {{slug, title, price, sizes}, position} ->
      attrs = %{
        "external_id" => slug,
        "title" => title,
        "description" =>
          "#{title} demo listing. Fictional price and stock for interface testing.",
        "price" => price,
        "currency" => "KES",
        "image_url" => "#{image_base}/#{slug}.webp",
        "source" => "manual",
        "status" => "active",
        "sort_order" => position,
        "metadata" => %{
          "category" => "Sneakers",
          "stock_status" => "in_stock",
          "demo_data" => true,
          "variants" => Enum.map(sizes, &%{"label" => "EU #{&1}", "price" => price})
        }
      }

      attrs =
        case Repo.get_by(Item, catalog_id: catalog.id, external_id: slug) do
          nil -> attrs
          item -> Map.put(attrs, "id", item.id)
        end

      {:ok, _item} = Catalogs.upsert_item(catalog, attrs)
    end)

    trigger = "When the shopper asks to browse shoes or see what is available"

    attrs = %{
      cta_type: "reply_buttons",
      trigger_description: trigger,
      cta_payload: %{"buttons" => ["Adidas Spezial", "Nike Shox", "Onitsuka Tigers"]},
      priority: 1
    }

    case Enum.find(CTARules.list_cta_rules(workspace.id), &(&1.trigger_description == trigger)) do
      nil -> {:ok, _rule} = CTARules.create_cta_rule(workspace.id, attrs)
      rule -> {:ok, _rule} = CTARules.update_cta_rule(rule, attrs)
    end

    workspace
  end)

IO.puts("""

Soko Shoes demo ready
  Email: #{email}
  Password: #{password}
  Workspace: /workspaces/#{workspace.id}
  Playground: /workspaces/#{workspace.id}/playground
  Products: Adidas Spezial, Nike Shox, Onitsuka Tigers
  Prices, sizes, and stock are fictional demo data.
  Add OPENAI_API_KEY to .env and restart Phoenix before chatting.
""")
