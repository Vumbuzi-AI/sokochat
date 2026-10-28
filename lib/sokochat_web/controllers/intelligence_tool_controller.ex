defmodule SokochatWeb.IntelligenceToolController do
  @moduledoc "Private, read-only business capabilities for the Pi harness."
  use SokochatWeb, :controller
  import Ecto.Query

  alias Sokochat.{Catalogs, Repo}
  alias Sokochat.Catalogs.{Catalog, Item}
  alias Sokochat.Conversations.{Conversation, Message}
  alias Sokochat.Workspaces.Workspace

  plug :authorize_scope

  def show(conn, %{"tool" => tool} = params) do
    workspace = conn.assigns.intelligence_workspace

    case tool do
      "shop_profile" ->
        json(
          conn,
          Map.take(workspace, [:name, :company_name, :industry, :location, :phone_number, :about])
        )

      "list_categories" ->
        json(conn, %{categories: Catalogs.list_item_categories(workspace.id)})

      "search_products" ->
        query = params |> Map.get("query", "") |> String.slice(0, 160) |> String.trim()
        offset = integer(params["offset"], 0, 0, 10_000)
        category = params["category"]
        items = scoped_items(workspace.id)

        items =
          if query == "", do: items, else: where(items, [i], ilike(i.title, ^pattern(query)))

        items =
          if category in [nil, ""],
            do: items,
            else:
              where(
                items,
                [i],
                fragment("lower(?->>'category') = lower(?)", i.metadata, ^category)
              )

        results =
          items
          |> order_by([i], asc: i.sort_order, asc: i.id)
          |> offset(^offset)
          |> limit(13)
          |> Repo.all()

        json(conn, %{
          items: Enum.map(Enum.take(results, 12), &Catalogs.item_context/1),
          next_offset: if(length(results) > 12, do: offset + 12, else: nil)
        })

      "get_product" ->
        identifier = String.slice(params["product_id"] || "", 0, 120)

        item =
          if Regex.match?(~r/^\d+$/, identifier) do
            scoped_items(workspace.id)
            |> where(
              [i],
              fragment("?::text = ?", i.id, ^identifier) or i.external_id == ^identifier
            )
            |> limit(1)
            |> Repo.one()
          else
            scoped_items(workspace.id)
            |> where([i], i.external_id == ^identifier)
            |> limit(1)
            |> Repo.one()
          end

        if item,
          do: json(conn, %{item: Catalogs.item_context(item)}),
          else: conn |> put_status(:not_found) |> json(%{error: "Product not found"})

      _ ->
        conn |> put_status(:not_found) |> json(%{error: "Unknown tool"})
    end
  end

  defp scoped_items(workspace_id) do
    from i in Item,
      join: c in Catalog,
      on: c.id == i.catalog_id,
      where: c.workspace_id == ^workspace_id and i.status == "active"
  end

  defp authorize_scope(conn, _opts) do
    secret = Application.get_env(:sokochat, :intelligence, []) |> Keyword.get(:pi_token)
    [authorization] = (get_req_header(conn, "authorization") ++ [nil]) |> Enum.take(1)

    authorized =
      is_binary(secret) and byte_size(secret) >= 32 and is_binary(authorization) and
        Plug.Crypto.secure_compare(
          :crypto.hash(:sha256, authorization),
          :crypto.hash(:sha256, "Bearer " <> secret)
        )

    with true <- authorized,
         {workspace_id, ""} <- Integer.parse(conn.params["workspace_id"] || ""),
         {conversation_id, ""} <- Integer.parse(conn.params["conversation_id"] || ""),
         ["message-" <> message_id] <- get_req_header(conn, "x-pi-request-id"),
         {message_id, ""} <- Integer.parse(message_id),
         true <-
           Repo.exists?(
             from m in Message,
               join: c in Conversation,
               on: c.id == m.conversation_id,
               join: t in Sokochat.Conversations.AiTurn,
               on: t.user_message_id == m.id and t.status == "queued",
               where:
                 m.id == ^message_id and m.role == "user" and c.id == ^conversation_id and
                   c.workspace_id == ^workspace_id
           ),
         %Workspace{} = workspace <- Repo.get(Workspace, workspace_id),
         true <- workspace.data_source == "manual" do
      assign(conn, :intelligence_workspace, workspace)
    else
      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Unauthorized tool scope"}) |> halt()
    end
  end

  defp pattern(query) do
    escaped =
      query
      |> String.replace("\\", "\\\\")
      |> String.replace("%", "\\%")
      |> String.replace("_", "\\_")

    "%" <> escaped <> "%"
  end

  defp integer(value, default, low, high) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> number |> max(low) |> min(high)
      _ -> default
    end
  end

  defp integer(_, default, _, _), do: default
end
