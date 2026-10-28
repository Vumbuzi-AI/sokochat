defmodule Sokochat.Conversations.DurableTurnsTest do
  use Sokochat.DataCase, async: false
  import Sokochat.AccountsFixtures
  import Sokochat.WorkspacesFixtures
  alias Sokochat.{Conversations, Repo}
  alias Sokochat.Conversations.{AiTurn, DurableTurns}

  setup do
    workspace = workspace_fixture(user_fixture())
    %{prepared: %{workspace: workspace, endpoint: nil}}
  end

  test "duplicate inbound delivery reacquires a turn without inserting another buyer message", %{
    prepared: prepared
  } do
    opts = [wait: false, source_key: "whatsapp:wamid-123"]

    assert {:ok, first} =
             DurableTurns.dispatch(prepared, "buyer-1", "Hello", :whatsapp, "Shop prompt", opts)

    assert {:ok, second} =
             DurableTurns.dispatch(
               prepared,
               "buyer-1",
               "Hello",
               :whatsapp,
               "Updated prompt",
               opts
             )

    assert first.id == second.id
    assert length(Conversations.list_messages(first.conversation_id)) == 1
  end

  test "reconciliation commits one assistant message when a result is delivered repeatedly", %{
    prepared: prepared
  } do
    {:ok, turn} =
      DurableTurns.dispatch(prepared, "buyer-1", "Hello", :playground, "Shop prompt", wait: false)

    reply = %{reply: "Hello there!", cta: nil, policy: "ok", tokens: 10}
    assert :ok = DurableTurns.complete(turn.id, reply)
    assert :ok = DurableTurns.complete(turn.id, reply)

    assert Enum.count(
             Conversations.list_messages(turn.conversation_id),
             &(&1.role == "assistant")
           ) == 1
  end

  test "later turns wait until earlier turns in the same conversation settle", %{
    prepared: prepared
  } do
    {:ok, first} =
      DurableTurns.dispatch(prepared, "buyer-1", "Hello", :playground, "Shop prompt", wait: false)

    {:ok, second} =
      DurableTurns.dispatch(prepared, "buyer-1", "Show shoes", :playground, "Shop prompt",
        wait: false
      )

    assert DurableTurns.earlier_pending?(second)
    :ok = DurableTurns.fail(first.id, "Could not answer")
    refute DurableTurns.earlier_pending?(second)
  end

  test "a send interrupted after its intent was stored becomes uncertain without resending", %{
    prepared: prepared
  } do
    {:ok, turn} =
      DurableTurns.dispatch(prepared, "buyer-1", "Hello", :whatsapp, "Shop prompt", wait: false)

    turn
    |> Ecto.Changeset.change(status: "completed", delivery_status: "sending")
    |> Repo.update!()

    assert :ok = Sokochat.Workers.DeliverAiReply.perform(%Oban.Job{args: %{"turn_id" => turn.id}})
    assert Repo.get!(AiTurn, turn.id).delivery_status == "uncertain"
  end
end
