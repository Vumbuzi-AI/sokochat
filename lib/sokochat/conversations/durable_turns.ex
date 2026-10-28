defmodule Sokochat.Conversations.DurableTurns do
  @moduledoc "Postgres admission, ordered execution, and idempotent reply persistence for Pi turns."
  import Ecto.Query
  alias Sokochat.{Conversations, Repo}
  alias Sokochat.Conversations.{AiTurn, Conversation, Message, ProductCTA}
  alias Sokochat.AI.OpenAIClient

  def dispatch(prepared, phone, text, source, instructions, opts) do
    case admit(prepared, phone, text, source, instructions, opts) do
      {:ok, turn} ->
        if Keyword.get(opts, :wait, true),
          do: await(turn.id, System.monotonic_time(:millisecond) + 90_000),
          else: {:ok, turn}

      error ->
        error
    end
  end

  defp admit(prepared, phone, text, source, instructions, opts) do
    Repo.transaction(fn ->
      Repo.one!(
        from w in Sokochat.Workspaces.Workspace,
          where: w.id == ^prepared.workspace.id,
          lock: "FOR UPDATE"
      )

      {:ok, conversation} =
        Conversations.get_or_create_conversation(prepared.workspace.id, phone, source)

      # Serializes admission for this conversation, including duplicate webhooks.
      Repo.one!(from c in Conversation, where: c.id == ^conversation.id, lock: "FOR UPDATE")
      key = Keyword.get(opts, :source_key)

      existing =
        if key, do: Repo.get_by(AiTurn, workspace_id: prepared.workspace.id, source_key: key)

      if existing do
        existing
      else
        queued =
          Repo.aggregate(
            from(t in AiTurn,
              where: t.workspace_id == ^prepared.workspace.id and t.status == "queued"
            ),
            :count
          )

        if queued >= 25,
          do: Repo.rollback("This shop's assistant is busy. Please try again shortly.")

        {:ok, message} = Conversations.add_message(conversation, :user, text)

        turn =
          Repo.insert!(%AiTurn{
            workspace_id: prepared.workspace.id,
            conversation_id: conversation.id,
            user_message_id: message.id,
            source_key: key,
            instructions: instructions,
            tool_mode:
              if(prepared.workspace.data_source == "manual" and is_nil(prepared.endpoint),
                do: "catalog",
                else: "context"
              )
          })

        %{turn_id: turn.id} |> Sokochat.Workers.RunAiTurn.new() |> Oban.insert!()
        turn
      end
    end)
  end

  def payload(turn) do
    Repo.transaction(fn ->
      turn = Repo.one!(from t in AiTurn, where: t.id == ^turn.id, lock: "FOR UPDATE")

      if turn.payload do
        turn.payload
      else
        message = Repo.get!(Message, turn.user_message_id)
        # Prior turns have settled. Exclude future admitted user messages and put
        # this turn's input last, even if previous replies were inserted later.
        history =
          from(m in Message,
            where:
              m.conversation_id == ^turn.conversation_id and
                (m.role == "assistant" or m.id < ^message.id),
            order_by: [desc: m.id],
            limit: 10
          )
          |> Repo.all()
          |> Enum.reverse()
          |> Enum.map(&%{role: &1.role, content: &1.content})

        payload = %{
          workspace_id: turn.workspace_id,
          conversation_id: turn.conversation_id,
          request_id: "message-#{turn.user_message_id}",
          tool_mode: turn.tool_mode,
          instructions: turn.instructions,
          input: history ++ [%{role: "user", content: message.content}],
          response_format: OpenAIClient.response_format()
        }

        turn |> Ecto.Changeset.change(payload: payload) |> Repo.update!() |> Map.fetch!(:payload)
      end
    end)
  end

  def earlier_pending?(turn),
    do:
      Repo.exists?(
        from t in AiTurn,
          where:
            t.conversation_id == ^turn.conversation_id and t.id < ^turn.id and
              t.status == "queued"
      )

  def complete(turn_id, reply) do
    result =
      Repo.transaction(fn ->
        turn = Repo.one(from t in AiTurn, where: t.id == ^turn_id, lock: "FOR UPDATE")

        if turn && turn.status == "queued" do
          conversation =
            Repo.one!(
              from c in Conversation, where: c.id == ^turn.conversation_id, lock: "FOR UPDATE"
            )

          user_message = Repo.get!(Message, turn.user_message_id)

          cta =
            if reply.policy == "refuse" do
              Conversations.increment_policy_strikes(conversation)
              nil
            else
              # Reuse the channel card builder with authoritative workspace data.
              workspace = Repo.get!(Sokochat.Workspaces.Workspace, turn.workspace_id)

              context =
                if workspace.data_source == "manual" do
                  card_products(turn.workspace_id, user_message.content, reply)
                else
                  case Sokochat.Endpoints.get_endpoint(turn.workspace_id) do
                    nil -> %{}
                    endpoint -> endpoint.cached_data || %{}
                  end
                end

              cta =
                if workspace.data_source == "manual",
                  do: safe_manual_cta(workspace, context, reply.cta),
                  else: reply.cta

              ProductCTA.attach(reply.reply, user_message.content, context, cta)
            end

          {:ok, assistant} =
            Conversations.add_message(conversation, :assistant, reply.reply,
              cta: cta,
              tokens_used: reply.tokens
            )

          turn
          |> Ecto.Changeset.change(
            status: "completed",
            assistant_message_id: assistant.id,
            delivery_status: if(conversation.source == "whatsapp", do: "pending", else: "none")
          )
          |> Repo.update!()

          if conversation.source == "whatsapp",
            do: %{turn_id: turn.id} |> Sokochat.Workers.DeliverAiReply.new() |> Oban.insert!()

          {conversation, user_message, assistant}
        else
          nil
        end
      end)

    case result do
      {:ok, {conversation, user_message, assistant}} ->
        Conversations.broadcast_new_message(assistant)

        if conversation.source == "playground" do
          Conversations.broadcast_playground_message(conversation.workspace_id, user_message)
          Conversations.broadcast_playground_message(conversation.workspace_id, assistant)
        end

        :ok

      {:ok, nil} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp card_products(workspace_id, user_text, reply) do
    alias Sokochat.Catalogs.{Catalog, Item}
    identifier = get_in(reply.cta || %{}, ["payload", "product_id"])

    base =
      from i in Item,
        join: c in Catalog,
        on: c.id == i.catalog_id,
        where: c.workspace_id == ^workspace_id and i.status == "active"

    query =
      if is_binary(identifier) and identifier != "" do
        from i in base,
          where: i.external_id == ^identifier or fragment("?::text = ?", i.id, ^identifier)
      else
        from i in base,
          where:
            fragment("strpos(lower(?), lower(?)) > 0", ^user_text, i.title) or
              fragment("strpos(lower(?), lower(?)) > 0", ^reply.reply, i.title)
      end

    query |> limit(12) |> Repo.all() |> Enum.map(&Sokochat.Catalogs.item_context/1)
  end

  defp safe_manual_cta(_workspace, _products, nil), do: nil

  defp safe_manual_cta(workspace, products, %{"type" => type, "payload" => payload} = cta) do
    rules = Sokochat.CTARules.list_cta_rules(workspace.id)

    rule =
      Enum.find(rules, fn rule ->
        rule.cta_type == type and
          case type do
            "website" ->
              rule.cta_payload["url"] == payload["url"]

            kind when kind in ["phone", "whatsapp"] ->
              rule.cta_payload["number"] == payload["number"]

            "location" ->
              rule.cta_payload["latitude"] == payload["latitude"] and
                rule.cta_payload["longitude"] == payload["longitude"]

            _ ->
              false
          end
      end)

    cond do
      rule ->
        %{"type" => type, "payload" => rule.cta_payload}

      type == "catalog" and products == [] ->
        nil

      type == "catalog" ->
        cta

      type == "website" ->
        if Enum.any?(products, &(&1["url"] == payload["url"] and is_binary(payload["url"]))),
          do: cta,
          else: nil

      type in ["phone", "whatsapp"] ->
        numbers = [
          workspace.phone_number
          | Enum.flat_map(products, &[&1["phone_number"], &1["whatsapp_number"]])
        ]

        if is_binary(payload["number"]) and payload["number"] in numbers, do: cta, else: nil

      type == "location" ->
        nil

      true ->
        cta
    end
  end

  defp safe_manual_cta(_workspace, _products, _cta), do: nil

  def fail(turn_id, reason) do
    {count, _} =
      from(t in AiTurn, where: t.id == ^turn_id and t.status == "queued")
      |> Repo.update_all(
        set: [
          status: "failed",
          last_error: reason,
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        ]
      )

    if count == 1 do
      case Repo.get(AiTurn, turn_id) do
        %AiTurn{} = turn ->
          case Repo.get(Conversation, turn.conversation_id) do
            %Conversation{source: "playground"} ->
              Phoenix.PubSub.broadcast(
                Sokochat.PubSub,
                Conversations.playground_topic(turn.workspace_id),
                {:ai_turn_failed, turn.workspace_id, reason}
              )

            _ ->
              :ok
          end

        nil ->
          :ok
      end
    end

    :ok
  end

  defp await(id, deadline) do
    case Repo.get(AiTurn, id) do
      %AiTurn{status: "completed", assistant_message_id: message_id} ->
        {:ok, Repo.get!(Message, message_id)}

      %AiTurn{status: "failed", last_error: reason} ->
        {:error, reason}

      nil ->
        {:error, "This conversation was cleared."}

      _ ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, "Your reply is still being generated. It will appear here when ready."}
        else
          Process.sleep(500)
          await(id, deadline)
        end
    end
  end
end
