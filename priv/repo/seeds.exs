# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This seed creates a ready-to-demo account with:
#   * a confirmed owner user
#   * GS1 Kenya and Shamba Ikonet workspaces
#   * a product catalog for each workspace
#   * CTA rules for the common WhatsApp interaction types
#   * optional Meta credentials from `.env` / shell env
#
# It is intentionally idempotent, so you can re-run it safely while iterating.

Code.eval_file("seeds_shoes.exs", __DIR__)

import Ecto.Query

alias Sokochat.Accounts
alias Sokochat.Accounts.User
alias Sokochat.Catalogs
alias Sokochat.Catalogs.{Field, Item}
alias Sokochat.CTARules
alias Sokochat.Endpoints
alias Sokochat.Meta
alias Sokochat.Repo
alias Sokochat.Workspaces
alias Sokochat.Workspaces.Workspace

strip_wrapping_quotes = fn
  "\"" <> rest -> String.trim_trailing(rest, "\"")
  "'" <> rest -> String.trim_trailing(rest, "'")
  value -> value
end

dotenv =
  case File.read(Path.expand("../../.env", __DIR__)) do
    {:ok, contents} ->
      contents
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        trimmed = String.trim(line)

        with false <- trimmed == "" or String.starts_with?(trimmed, "#"),
             [key, value] <- String.split(String.trim_leading(trimmed, "export "), "=", parts: 2) do
          value =
            value
            |> String.trim()
            |> strip_wrapping_quotes.()

          Map.put(acc, String.trim(key), value)
        else
          _ -> acc
        end
      end)

    {:error, _} ->
      %{}
  end

env_value = fn key, default ->
  case System.get_env(key) || Map.get(dotenv, key) || default do
    value when is_binary(value) ->
      trimmed = String.trim(value)
      if trimmed == "", do: nil, else: trimmed

    value ->
      value
  end
end

seed_email = env_value.("SEED_USER_EMAIL", "demo@sokochat.local")
seed_password = env_value.("SEED_USER_PASSWORD", "password123")
workspace_name = env_value.("SEED_WORKSPACE_NAME", "GS1 Kenya")
workspace_slug = env_value.("WA_WORKSPACE_SLUG", "gs1-kenya")

ensure_seed_user = fn email, name, password ->
  user =
    case Accounts.get_user_by_email(email) do
      %User{} = user ->
        user

      nil ->
        {:ok, user} =
          Accounts.register_user(%{
            name: name,
            email: email,
            password: password
          })

        user
    end

  user =
    user
    |> User.password_changeset(%{password: password})
    |> Repo.update!()

  if user.confirmed_at do
    user
  else
    user
    |> User.confirm_changeset()
    |> Repo.update!()
  end
end

seed_user = ensure_seed_user.(seed_email, "Demo Business Owner", seed_password)

workspace =
  case Repo.one(
         from w in Workspace,
           where: w.account_id == ^seed_user.id and w.slug == ^workspace_slug,
           limit: 1
       ) do
    %Workspace{} = workspace ->
      workspace

    nil ->
      {:ok, workspace} =
        Workspaces.create_workspace(
          %{
            name: workspace_name,
            language: "both",
            ai_instructions: """
            You are GS1 Kenya's WhatsApp assistant.
            Answer in a warm, concise way. Keep replies short enough for WhatsApp.
            Prefer specific product suggestions with price, stock status, delivery timing,
            and the best next action. If the buyer sounds ready to act, prefer a CTA over a
            long explanation.
            """
          },
          seed_user.id
        )

      workspace
  end

workspace =
  workspace
  |> Workspace.changeset(%{
    name: workspace_name,
    slug: workspace_slug,
    language: "both",
    data_source: "manual",
    company_name: "GS1 Kenya",
    industry: "Standards and business services",
    location: "Nairobi, Kenya",
    phone_number: "+254700000001",
    about:
      "GS1 Kenya provides globally recognized barcodes, identification standards, and business support services.",
    ai_instructions: """
    You are GS1 Kenya's WhatsApp assistant.
    Answer in a warm, concise way. Keep replies short enough for WhatsApp.
    Prefer specific product suggestions with price, stock status, delivery timing,
    and the best next action. If the buyer sounds ready to act, prefer a CTA over a
    long explanation.
    """
  })
  |> Repo.update!()

shamba_workspace =
  case Repo.one(
         from w in Workspace,
           where: w.account_id == ^seed_user.id and w.slug == "shamba-ikonet",
           limit: 1
       ) do
    %Workspace{} = workspace ->
      workspace

    nil ->
      {:ok, workspace} =
        Workspaces.create_workspace(
          %{
            name: "Shamba Ikonet",
            language: "both",
            ai_instructions:
              "You are Shamba Ikonet's friendly WhatsApp produce assistant. Help customers choose fresh vegetables, state prices clearly, and explain delivery options."
          },
          seed_user.id
        )

      workspace
  end

shamba_workspace =
  shamba_workspace
  |> Workspace.changeset(%{
    name: "Shamba Ikonet",
    slug: "shamba-ikonet",
    language: "both",
    data_source: "manual",
    company_name: "Shamba Ikonet",
    industry: "Fresh produce and agriculture",
    location: "Nairobi, Kenya",
    phone_number: "+254700000003",
    about: "A farm-to-market business selling fresh, locally grown vegetables.",
    ai_instructions:
      "You are Shamba Ikonet's friendly WhatsApp produce assistant. Help customers choose fresh vegetables, state prices clearly, and explain delivery options."
  })
  |> Repo.update!()

catalog_data = %{
  "shop" => %{
    "name" => "GS1 Kenya",
    "city" => "Nairobi",
    "hours" => "Mon-Sat 8:00-20:00",
    "delivery" => "Digital onboarding details are sent after payment"
  },
  "categories" => [
    %{"title" => "Barcodes", "description" => "GS1 identification and barcode services"},
    %{"title" => "Training", "description" => "Standards and implementation support"}
  ],
  "items" => [
    %{
      "id" => "barcode-starter-package",
      "name" => "Barcode Starter Package",
      "title" => "Barcode Starter Package",
      "description" => "GS1 barcode registration and onboarding for a growing business.",
      "price" => 7500,
      "currency" => "KES",
      "category" => "Barcodes",
      "stock_status" => "in_stock",
      "image_url" =>
        "https://images.unsplash.com/photo-1546094096-0df4bcaaa337?auto=format&fit=crop&w=1200&q=80",
      "url" => "https://www.gs1kenya.org/",
      "phone" => "+254700000001",
      "whatsapp_number" => "+254700000002"
    },
    %{
      "id" => "gs1-standards-training",
      "name" => "GS1 Standards Training",
      "title" => "GS1 Standards Training",
      "description" =>
        "Practical training on product identification, barcodes, and traceability.",
      "price" => 5000,
      "currency" => "KES",
      "category" => "Training",
      "stock_status" => "in_stock",
      "image_url" =>
        "https://images.unsplash.com/photo-1508747703725-719777637510?auto=format&fit=crop&w=1200&q=80",
      "url" => "https://www.gs1kenya.org/",
      "phone" => "+254700000001",
      "whatsapp_number" => "+254700000002"
    }
  ]
}

{:ok, endpoint} =
  Endpoints.upsert_endpoint(workspace.id, %{
    "url" => "https://example.com/gs1-kenya/catalog.json",
    "method" => "GET",
    "headers" => %{"Accept" => "application/json"},
    "refresh_strategy" => "poll_300s",
    "cached_data" => catalog_data,
    "last_fetched_at" => DateTime.utc_now() |> DateTime.truncate(:second)
  })

{:ok, catalog} =
  Catalogs.upsert_catalog(workspace.id, %{
    "name" => "GS1 Kenya service catalog",
    "entity_label" => "product",
    "context_notes" =>
      "Use category, stock_status, delivery_notes, and SKU metadata to answer product questions.",
    "categories" => ["Barcodes", "Training"]
  })

Repo.delete_all(
  from(field in Field, where: field.catalog_id == ^catalog.id and field.key == "category")
)

fields = [
  %{
    "key" => "stock_status",
    "label" => "Stock status",
    "field_type" => "text",
    "required" => true,
    "help_text" => "Availability shown in replies",
    "position" => 2
  },
  %{
    "key" => "delivery_notes",
    "label" => "Delivery notes",
    "field_type" => "textarea",
    "required" => false,
    "help_text" => "Delivery promise or limitation for this item",
    "position" => 3
  }
]

Enum.each(fields, fn attrs ->
  attrs =
    case Repo.get_by(Field, catalog_id: catalog.id, key: attrs["key"]) do
      nil -> attrs
      %Field{id: id} -> Map.put(attrs, "id", id)
    end

  {:ok, _field} = Catalogs.upsert_field(catalog, attrs)
end)

catalog_items =
  catalog_data["items"]
  |> Enum.with_index()
  |> Enum.map(fn {item, index} ->
    metadata =
      item
      |> Map.take(["category", "stock_status"])
      |> Map.put("delivery_notes", catalog_data["shop"]["delivery"])
      |> Map.put("sku", item["id"])

    %{
      "external_id" => item["id"],
      "title" => item["title"],
      "description" => item["description"],
      "price" => item["price"],
      "currency" => item["currency"],
      "image_url" => item["image_url"],
      "url" => item["url"],
      "phone_number" => item["phone"],
      "whatsapp_number" => item["whatsapp_number"],
      "metadata" => metadata,
      "source" => "manual",
      "status" => "active",
      "sort_order" => index + 1
    }
  end)

Enum.each(catalog_items, fn attrs ->
  attrs =
    case Repo.get_by(Item, catalog_id: catalog.id, external_id: attrs["external_id"]) do
      nil -> attrs
      %Item{id: id} -> Map.put(attrs, "id", id)
    end

  {:ok, _item} = Catalogs.upsert_item(catalog, attrs)
end)

{:ok, shamba_catalog} =
  Catalogs.upsert_catalog(shamba_workspace.id, %{
    "name" => "Shamba Ikonet vegetable catalog",
    "entity_label" => "vegetable",
    "context_notes" =>
      "Prices are in Kenyan shillings per stated unit. Use category, stock status, unit, and delivery notes when helping customers.",
    "categories" => ["Vegetables", "Leafy Vegetables"]
  })

Repo.delete_all(
  from(field in Field, where: field.catalog_id == ^shamba_catalog.id and field.key == "category")
)

Enum.each(fields, fn attrs ->
  attrs =
    case Repo.get_by(Field, catalog_id: shamba_catalog.id, key: attrs["key"]) do
      nil -> attrs
      %Field{id: id} -> Map.put(attrs, "id", id)
    end

  {:ok, _field} = Catalogs.upsert_field(shamba_catalog, attrs)
end)

shamba_items = [
  %{
    "external_id" => "fresh-tomatoes",
    "title" => "Fresh Tomatoes",
    "description" => "Ripe, firm, locally grown tomatoes sold per kilogram.",
    "price" => 120,
    "currency" => "KES",
    "image_url" =>
      "https://images.unsplash.com/photo-1546094096-0df4bcaaa337?auto=format&fit=crop&w=1200&q=80",
    "metadata" => %{
      "category" => "Vegetables",
      "stock_status" => "in_stock",
      "unit" => "1 kg",
      "delivery_notes" => "Same-day delivery in Nairobi for orders placed before 2pm"
    }
  },
  %{
    "external_id" => "sukuma-wiki",
    "title" => "Sukuma Wiki",
    "description" => "Freshly harvested collard greens bundled on the day of delivery.",
    "price" => 50,
    "currency" => "KES",
    "image_url" =>
      "https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=1200&q=80",
    "metadata" => %{
      "category" => "Leafy Vegetables",
      "stock_status" => "in_stock",
      "unit" => "1 bunch",
      "delivery_notes" => "Same-day delivery in Nairobi for orders placed before 2pm"
    }
  },
  %{
    "external_id" => "spinach-bunch",
    "title" => "Fresh Spinach",
    "description" => "Tender green spinach, cleaned and tied in a generous bunch.",
    "price" => 60,
    "currency" => "KES",
    "image_url" =>
      "https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=1200&q=80",
    "metadata" => %{
      "category" => "Leafy Vegetables",
      "stock_status" => "in_stock",
      "unit" => "1 bunch",
      "delivery_notes" => "Same-day delivery in Nairobi for orders placed before 2pm"
    }
  },
  %{
    "external_id" => "red-onions",
    "title" => "Red Onions",
    "description" => "Clean, medium-sized red onions sold per kilogram.",
    "price" => 110,
    "currency" => "KES",
    "image_url" =>
      "https://images.unsplash.com/photo-1508747703725-719777637510?auto=format&fit=crop&w=1200&q=80",
    "metadata" => %{
      "category" => "Vegetables",
      "stock_status" => "in_stock",
      "unit" => "1 kg",
      "delivery_notes" => "Same-day delivery in Nairobi for orders placed before 2pm"
    }
  },
  %{
    "external_id" => "green-capsicum",
    "title" => "Green Capsicum",
    "description" => "Crisp green capsicum suitable for salads, stews, and stir-fries.",
    "price" => 180,
    "currency" => "KES",
    "image_url" =>
      "https://images.unsplash.com/photo-1563565375-f3fdfdbefa83?auto=format&fit=crop&w=1200&q=80",
    "metadata" => %{
      "category" => "Vegetables",
      "stock_status" => "in_stock",
      "unit" => "1 kg",
      "delivery_notes" => "Same-day delivery in Nairobi for orders placed before 2pm"
    }
  }
]

shamba_catalog_items =
  shamba_items
  |> Enum.with_index(1)
  |> Enum.map(fn {attrs, sort_order} ->
    attrs
    |> Map.put("phone_number", "+254700000003")
    |> Map.put("whatsapp_number", "+254700000003")
    |> Map.put("source", "manual")
    |> Map.put("status", "active")
    |> Map.put("sort_order", sort_order)
  end)

Enum.each(shamba_catalog_items, fn attrs ->
  attrs =
    case Repo.get_by(Item,
           catalog_id: shamba_catalog.id,
           external_id: attrs["external_id"]
         ) do
      nil -> attrs
      %Item{id: id} -> Map.put(attrs, "id", id)
    end

  {:ok, _item} = Catalogs.upsert_item(shamba_catalog, attrs)
end)

rules = [
  %{
    cta_type: "website",
    trigger_description:
      "When the buyer asks to browse the full catalog, website, or shop online",
    cta_payload: %{
      "title" => "Open catalog",
      "url" => "https://shop.example.com",
      "image_url" =>
        "https://images.unsplash.com/photo-1488459716781-31db52582fe9?auto=format&fit=crop&w=1200&q=80"
    }
  },
  %{
    cta_type: "phone",
    trigger_description: "When the buyer asks to call the shop or speak to the team by phone",
    cta_payload: %{"number" => "+254700000001"}
  },
  %{
    cta_type: "whatsapp",
    trigger_description: "When the buyer asks to chat with a human agent on WhatsApp",
    cta_payload: %{"number" => "+254700000002"}
  },
  %{
    cta_type: "reply_buttons",
    trigger_description: "When the buyer asks about payment methods or how they can pay",
    cta_payload: %{
      "title" => "Payment options",
      "body" => "How would you like to pay?",
      "buttons" => ["M-Pesa", "Card", "Cash on delivery"]
    }
  },
  %{
    cta_type: "list_message",
    trigger_description:
      "When the buyer asks what categories, departments, or collections are available",
    cta_payload: %{
      "title" => "Browse categories",
      "body" => "Choose a category to explore",
      "items" => [
        %{"title" => "Barcodes", "description" => "Identification and barcode services"},
        %{"title" => "Training", "description" => "Standards and implementation support"}
      ]
    }
  },
  %{
    cta_type: "location",
    trigger_description: "When the buyer asks where the shop is located or wants directions",
    cta_payload: %{
      "title" => "GS1 Kenya",
      "address" => "Nairobi, Kenya",
      "latitude" => -1.2833,
      "longitude" => 36.8167
    }
  },
  %{
    cta_type: "catalog",
    trigger_description: "When the buyer specifically asks to see the Barcode Starter Package",
    cta_payload: %{"product_id" => "barcode-starter-package"}
  },
  %{
    cta_type: "custom",
    trigger_description:
      "When the buyer asks about delivery timing, shipping speed, or how long orders take",
    cta_payload: %{
      "template" =>
        "Standard Nairobi delivery is same-day for orders before 4pm. Upcountry delivery is usually 1-3 business days."
    }
  }
]

existing_rules =
  workspace.id
  |> CTARules.list_cta_rules()
  |> Map.new(&{&1.trigger_description, &1})

Enum.with_index(rules, 1)
|> Enum.each(fn {rule, priority} ->
  attrs = Map.put(rule, :priority, priority)

  case Map.get(existing_rules, rule.trigger_description) do
    nil ->
      {:ok, _} = CTARules.create_cta_rule(workspace.id, attrs)

    existing_rule ->
      {:ok, _} = CTARules.update_cta_rule(existing_rule, attrs)
  end
end)

wa_values = %{
  "phone_number_id" => env_value.("WA_PHONE_NUMBER_ID", nil),
  "waba_id" => env_value.("WA_WABA_ID", nil),
  "access_token" => env_value.("WA_ACCESS_TOKEN", nil)
}

present_wa_keys =
  wa_values
  |> Enum.filter(fn {_key, value} -> is_binary(value) and value != "" end)
  |> Enum.map(&elem(&1, 0))

connection_result =
  cond do
    map_size(Map.reject(wa_values, fn {_key, value} -> is_nil(value) end)) == 3 ->
      {:ok, connection} = Meta.upsert_connection(workspace.id, wa_values)
      {:seeded_meta, connection}

    present_wa_keys == [] ->
      :missing_meta_env

    true ->
      missing =
        ["phone_number_id", "waba_id", "access_token"]
        |> Enum.reject(&(&1 in present_wa_keys))
        |> Enum.join(", ")

      {:partial_meta_env, missing}
  end

dashboard_path = "/workspaces/#{workspace.id}"
meta_path = "/workspaces/#{workspace.id}/meta"

IO.puts("""

Sokochat demo data ready

  Owner email:     #{seed_user.email}
  Owner password:  #{seed_password}
  Workspace:       #{workspace.name} (id: #{workspace.id})
  Workspace slug:  #{workspace.slug}
  Second workspace: #{shamba_workspace.name} (id: #{shamba_workspace.id})
  Dashboard:       #{dashboard_path}
  Meta page:       #{meta_path}
  Endpoint URL:    #{endpoint.url}
  CTA rules:       #{length(rules)} seeded
  GS1 items:       #{length(catalog_items)}
  Shamba items:    #{length(shamba_catalog_items)}
""")

case connection_result do
  {:seeded_meta, connection} ->
    IO.puts("""
      Meta credentials: saved to workspace in pending mode
      Phone number ID:  #{connection.phone_number_id}
      Verify token:     #{connection.verify_token}

    Next on Meta:
      1. Open #{meta_path}
      2. Copy the Callback URL and Verify token into Meta > WhatsApp > Configuration
      3. Subscribe to the messages field and verify the webhook
    """)

  :missing_meta_env ->
    IO.puts("""
      Meta credentials: not seeded

    To finish Meta setup, add these to `.env` and re-run seeds:
      WA_PHONE_NUMBER_ID
      WA_WABA_ID
      WA_ACCESS_TOKEN
    """)

  {:partial_meta_env, missing} ->
    IO.puts("""
      Meta credentials: partially provided, not saved
      Missing values:   #{missing}

    Add the missing WA_* values to `.env` and re-run seeds to prefill the Meta page.
    """)
end
