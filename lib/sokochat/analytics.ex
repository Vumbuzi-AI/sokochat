defmodule Sokochat.Analytics do
  @moduledoc """
  Workspace activity for the analytics tab.

  Counts conversations, buyer messages, replies, and messages that carried a
  CTA. Week and month windows match the partners dashboard.
  """

  import Ecto.Query

  alias Sokochat.Conversations.Conversation
  alias Sokochat.Conversations.Message
  alias Sokochat.Repo

  def overview(workspace_id, range) when range in ["week", "month"] do
    days = if(range == "week", do: 7, else: 30)
    today = Date.utc_today()
    start_date = Date.add(today, -(days - 1))
    previous_start = Date.add(start_date, -days)
    start_at = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    previous_at = DateTime.new!(previous_start, ~T[00:00:00], "Etc/UTC")

    current = messages(workspace_id, start_at, nil)
    previous = messages(workspace_id, previous_at, start_at)
    by_day = group_days(current, start_date, days)
    totals = summarize(current)
    previous_totals = summarize(previous)

    ceil =
      by_day
      |> Enum.map(&max(&1.buyer, &1.ctas))
      |> Enum.max()
      |> max(1)

    %{
      range: range,
      caption: if(range == "week", do: "Last 7 days", else: "Last 30 days"),
      ceil: ceil,
      kpis: [
        kpi(
          "conversations",
          "Conversations",
          totals.conversations,
          previous_totals.conversations,
          spark(by_day, :conversations)
        ),
        kpi(
          "messages",
          "Buyer messages",
          totals.buyer,
          previous_totals.buyer,
          spark(by_day, :buyer)
        ),
        kpi(
          "replies",
          "Replies",
          totals.replies,
          previous_totals.replies,
          spark(by_day, :replies)
        ),
        kpi("ctas", "CTA sends", totals.ctas, previous_totals.ctas, spark(by_day, :ctas))
      ],
      days: by_day,
      leaders: leaders(by_day)
    }
  end

  defp messages(workspace_id, from, until) do
    query =
      from m in Message,
        join: c in Conversation,
        on: c.id == m.conversation_id,
        where: c.workspace_id == ^workspace_id and m.inserted_at >= ^from,
        select: %{
          conversation_id: c.id,
          role: m.role,
          at: m.inserted_at,
          cta: m.cta
        }

    query =
      if until do
        where(query, [m], m.inserted_at < ^until)
      else
        query
      end

    Repo.all(query)
  end

  defp summarize(rows) do
    %{
      conversations: rows |> Enum.map(& &1.conversation_id) |> Enum.uniq() |> length(),
      buyer: Enum.count(rows, &(&1.role == "user")),
      replies: Enum.count(rows, &(&1.role == "assistant")),
      ctas: Enum.count(rows, &(not is_nil(&1.cta)))
    }
  end

  defp group_days(rows, start_date, days) do
    grouped =
      Enum.group_by(rows, fn row -> DateTime.to_date(row.at) end)

    for offset <- 0..(days - 1) do
      date = Date.add(start_date, offset)
      day_rows = Map.get(grouped, date, [])

      %{
        date: date,
        conversations: day_rows |> Enum.map(& &1.conversation_id) |> Enum.uniq() |> length(),
        buyer: Enum.count(day_rows, &(&1.role == "user")),
        replies: Enum.count(day_rows, &(&1.role == "assistant")),
        ctas: Enum.count(day_rows, &(not is_nil(&1.cta)))
      }
    end
  end

  defp kpi(id, label, current, previous, spark) do
    %{
      id: id,
      label: label,
      value: Integer.to_string(current),
      delta: delta(current, previous),
      spark: spark
    }
  end

  defp delta(_current, 0), do: nil

  defp delta(current, previous) do
    round((current - previous) / previous * 100)
  end

  defp spark(days, key), do: Enum.map(days, &Map.fetch!(&1, key))

  defp leaders(days) do
    peak = days |> Enum.map(& &1.buyer) |> Enum.max()

    days
    |> Enum.sort_by(& &1.buyer, :desc)
    |> Enum.take(3)
    |> Enum.reject(&(&1.buyer == 0))
    |> Enum.map(fn day ->
      %{
        label: Calendar.strftime(day.date, "%b %-d"),
        buyer: day.buyer,
        ctas: day.ctas,
        share: if(peak == 0, do: 0, else: day.buyer / peak)
      }
    end)
  end
end
