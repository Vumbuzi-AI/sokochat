defmodule Sokochat.Marketplace.Orders do
  @moduledoc "Confirmed unpaid requests, scoped to their product owner. No model writes."
  import Ecto.Query
  alias Sokochat.{Marketplace, Repo}
  alias Sokochat.Marketplace.OrderRequest

  def draft(workspace, phone, item_id, source_key) when is_binary(source_key) do
    with item when not is_nil(item) <- Marketplace.get_product(workspace, item_id) do
      product = Marketplace.product_context(item)
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      # insert_all ON CONFLICT keeps a repeated webhook tied to its original draft.
      Repo.insert_all(
        OrderRequest,
        [
          %{
            workspace_id: product["seller_id"],
            shared_line_id: workspace.shared_line_id,
            item_id: item.id,
            phone_number: phone,
            source_key: source_key,
            product: product,
            status: "draft",
            inserted_at: now,
            updated_at: now
          }
        ],
        on_conflict: :nothing,
        conflict_target: [:shared_line_id, :source_key]
      )

      {:ok,
       Repo.get_by!(OrderRequest,
         shared_line_id: workspace.shared_line_id,
         source_key: source_key
       )}
    else
      _ -> {:error, :unavailable}
    end
  end

  def draft(_, _, _, _), do: {:error, :unavailable}

  def confirm(workspace, phone, id) do
    Repo.transaction(fn ->
      order =
        from(o in OrderRequest,
          where:
            o.id == ^(Marketplace.parse_id(id) || 0) and
              o.shared_line_id == ^workspace.shared_line_id and o.phone_number == ^phone,
          lock: "FOR UPDATE"
        )
        |> Repo.one()

      cond do
        is_nil(order) ->
          Repo.rollback(:unavailable)

        order.status in ["requested", "contacted"] ->
          order

        DateTime.diff(DateTime.utc_now(), order.inserted_at) > 1800 ->
          Repo.rollback(:expired)

        true ->
          item = Marketplace.get_product(workspace, order.item_id)
          if is_nil(item), do: Repo.rollback(:unavailable)
          current = Marketplace.product_context(item)
          if current != order.product, do: Repo.rollback(:changed)

          shop =
            Repo.one!(
              from s in Sokochat.Workspaces.Workspace,
                where: s.id == ^order.workspace_id,
                lock: "FOR SHARE"
            )

          fulfillment =
            if is_nil(order.fulfillment) && !Sokochat.Marketplace.Fulfillment.configured?(shop),
              do: %{"method" => "merchant", "fee" => nil},
              else: order.fulfillment

          if !Sokochat.Marketplace.Fulfillment.valid?(shop, fulfillment),
            do: Repo.rollback(:fulfillment_changed)

          order
          |> Ecto.Changeset.change(
            status: "requested",
            fulfillment: fulfillment,
            requested_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )
          |> Repo.update!()
      end
    end)
    |> case do
      {:ok, order} ->
        Phoenix.PubSub.broadcast(Sokochat.PubSub, topic(order.workspace_id), :orders_changed)
        {:ok, order}

      error ->
        error
    end
  end

  def get_draft(workspace, phone, id) do
    from(o in OrderRequest,
      where:
        o.id == ^(Marketplace.parse_id(id) || 0) and o.shared_line_id == ^workspace.shared_line_id and
          o.phone_number == ^phone
    )
    |> Repo.one()
    |> case do
      %{status: "draft"} = order ->
        if DateTime.diff(DateTime.utc_now(), order.inserted_at) <= 1800,
          do: {:ok, order},
          else: {:error, :expired}

      _ ->
        {:error, :unavailable}
    end
  end

  def set_fulfillment(workspace, phone, id, build) do
    Repo.transaction(fn ->
      order =
        Repo.one(
          from o in OrderRequest,
            where:
              o.id == ^(Marketplace.parse_id(id) || 0) and
                o.shared_line_id == ^workspace.shared_line_id and o.phone_number == ^phone,
            lock: "FOR UPDATE"
        )

      if is_nil(order) || order.status != "draft", do: Repo.rollback(:unavailable)
      if DateTime.diff(DateTime.utc_now(), order.inserted_at) > 1800, do: Repo.rollback(:expired)

      case build.(order) do
        {:ok, details} -> order |> Ecto.Changeset.change(fulfillment: details) |> Repo.update!()
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def pending_address(workspace, phone) do
    cutoff = DateTime.utc_now() |> DateTime.add(-1800, :second)

    Repo.one(
      from o in OrderRequest,
        where:
          o.shared_line_id == ^workspace.shared_line_id and o.phone_number == ^phone and
            o.status == "draft" and o.inserted_at > ^cutoff and
            fragment("?->>'awaiting_address' = 'true'", o.fulfillment),
        order_by: [desc: o.id],
        limit: 1
    )
  end

  def cancel_address(workspace, phone) do
    from(o in OrderRequest,
      where:
        o.shared_line_id == ^workspace.shared_line_id and o.phone_number == ^phone and
          o.status == "draft" and fragment("?->>'awaiting_address' = 'true'", o.fulfillment)
    )
    |> Repo.update_all(set: [fulfillment: nil])
  end

  @doc """
  Counts of order requests still waiting for the merchant, keyed by workspace id.

  Drafts and contacted requests are not included.
  """
  def pending_counts([]), do: %{}

  def pending_counts(workspace_ids) when is_list(workspace_ids) do
    from(o in OrderRequest,
      where: o.workspace_id in ^workspace_ids and o.status == "requested",
      group_by: o.workspace_id,
      select: {o.workspace_id, count(o.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def list(workspace_id) do
    from(o in OrderRequest,
      where: o.workspace_id == ^workspace_id and o.status != "draft",
      order_by: [desc: o.requested_at, desc: o.id]
    )
    |> Repo.all()
  end

  @doc "Marks every open request for the shop as contacted and tells open desks."
  def mark_all_contacted(workspace_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      from o in OrderRequest,
        where: o.workspace_id == ^workspace_id and o.status == "requested"

    case Repo.update_all(query, set: [status: "contacted", contacted_at: now, updated_at: now]) do
      {count, _} when count > 0 ->
        Phoenix.PubSub.broadcast(Sokochat.PubSub, topic(workspace_id), :orders_changed)
        {:ok, count}

      _ ->
        {:ok, 0}
    end
  end

  def mark_contacted(workspace_id, id) do
    query =
      from o in OrderRequest,
        where:
          o.workspace_id == ^workspace_id and
            o.id == ^(Marketplace.parse_id(id) || 0) and o.status == "requested"

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.update_all(query, set: [status: "contacted", contacted_at: now, updated_at: now]) do
      {1, _} ->
        Phoenix.PubSub.broadcast(Sokochat.PubSub, topic(workspace_id), :orders_changed)
        :ok

      _ ->
        {:error, :not_found}
    end
  end

  def topic(id), do: "marketplace:orders:#{id}"
end
