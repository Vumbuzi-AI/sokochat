defmodule SokochatWeb.WorkspacesLive.Analytics do
  use SokochatWeb, :live_view

  import SokochatWeb.WorkspaceShell

  alias Sokochat.Analytics
  alias Sokochat.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Analytics")
     |> assign(:workspaces, Workspaces.list_workspaces(socket.assigns.current_user.id))
     |> assign(:workspace, nil)
     |> assign(:range, "week"), layout: false}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        {:noreply, socket |> assign(:workspace, workspace) |> load_overview()}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  @impl true
  def handle_event("set_range", %{"range" => range}, socket) when range in ["week", "month"] do
    {:noreply, socket |> assign(:range, range) |> load_overview()}
  end

  defp load_overview(socket) do
    assign(
      socket,
      :overview,
      Analytics.overview(socket.assigns.workspace.id, socket.assigns.range)
    )
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.shell
      :if={@workspace}
      workspace={@workspace}
      workspaces={@workspaces}
      current_user={@current_user}
      tab={:analytics}
      title="Analytics"
      subtitle="Messages and next steps"
      flash={@flash}
      inbox_counts={@inbox_counts}
    >
      <.overview overview={@overview} />
    </.shell>
    """
  end

  attr :overview, :map, required: true

  defp overview(assigns) do
    ticks = [assigns.overview.ceil, div(assigns.overview.ceil, 2), 0]
    assigns = assign(assigns, :ticks, ticks)

    ~H"""
    <section class="soko-overview" aria-label="Shop analytics">
      <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
        <p class="text-sm text-soko-ink-2">{@overview.caption}</p>
        <div class="soko-segmented" role="group" aria-label="Date range">
          <label :for={{id, label} <- [{"week", "Week"}, {"month", "Month"}]}>
            <input
              type="radio"
              name="range"
              value={id}
              checked={@overview.range == id}
              phx-click="set_range"
              phx-value-range={id}
            />
            {label}
          </label>
        </div>
      </div>

      <ul class="soko-kpis" aria-label="Key numbers">
        <li :for={kpi <- @overview.kpis} class="soko-card flex flex-col">
          <span class="text-xs text-soko-ink-2">{kpi.label}</span>
          <div class="mt-2 flex items-center justify-between gap-2">
            <p class="soko-heading text-[26px] tabular-nums leading-none">{kpi.value}</p>
            <.badge :if={kpi.delta} tone={if kpi.delta > 0, do: "success", else: "danger"}>
              {if kpi.delta > 0, do: "+", else: "−"}{abs(kpi.delta)}%
            </.badge>
          </div>
          <svg
            :if={Enum.any?(kpi.spark, &(&1 > 0))}
            viewBox="0 0 120 28"
            class={[
              "mt-2 h-7 w-full",
              (is_nil(kpi.delta) or kpi.delta >= 0) && "text-soko-forest",
              kpi.delta && kpi.delta < 0 && "text-soko-danger"
            ]}
            aria-hidden="true"
          >
            <polyline
              points={spark_points(kpi.spark)}
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linejoin="round"
              stroke-linecap="round"
            />
          </svg>
        </li>
      </ul>

      <div class="soko-overview-grid">
        <section class="soko-card" aria-labelledby="activity-chart">
          <header class="mb-3 flex flex-wrap items-center justify-between gap-2">
            <h2 id="activity-chart" class="soko-section-title text-[16px]">Activity</h2>
            <ul class="flex flex-wrap justify-end gap-x-3 gap-y-1 text-xs text-soko-ink-2">
              <li class="inline-flex items-center gap-1.5">
                <i class="soko-series-a h-2 w-2 rounded-[2.5px]" aria-hidden="true"></i> Messages
              </li>
              <li class="inline-flex items-center gap-1.5">
                <i class="soko-series-b h-2 w-2 rounded-[2.5px]" aria-hidden="true"></i> Next steps
              </li>
            </ul>
          </header>
          <figure class="soko-chart" role="img" aria-label={chart_label(@overview.days)}>
            <div class="soko-chart-grid" aria-hidden="true">
              <span :for={tick <- @ticks} data-value={tick}></span>
            </div>
            <ol class="soko-chart-cols" style={"--cols: #{max(length(@overview.days), 1)}"}>
              <li :for={{day, index} <- Enum.with_index(@overview.days)} class="soko-chart-col">
                <div
                  class="soko-bars"
                  title={"#{day_label(day.date)} · #{day.buyer} messages · #{day.ctas} next steps"}
                >
                  <span
                    class="soko-bar soko-series-a"
                    style={"height: #{bar_pct(day.buyer, @overview.ceil)}%"}
                  >
                  </span>
                  <span
                    class="soko-bar soko-series-b"
                    style={"height: #{bar_pct(day.ctas, @overview.ceil)}%"}
                  >
                  </span>
                </div>
                <span
                  class="soko-chart-label"
                  style={
                    unless show_label?(index, @overview.range, length(@overview.days)),
                      do: "visibility: hidden"
                  }
                >
                  {day_label(day.date)}
                </span>
              </li>
            </ol>
          </figure>
        </section>

        <section class="soko-card" aria-labelledby="busiest-days">
          <h2 id="busiest-days" class="soko-section-title text-[16px]">Busiest days</h2>
          <ol :if={@overview.leaders != []} class="mt-3 flex flex-col gap-3">
            <li :for={day <- @overview.leaders}>
              <div class="flex items-baseline justify-between gap-2">
                <span class="text-sm font-medium">{day.label}</span>
                <span class="text-xs tabular-nums text-soko-ink-2">{day.buyer} messages</span>
              </div>
              <div class="mt-1.5 h-1 overflow-hidden rounded-full bg-soko-stage" aria-hidden="true">
                <span
                  class="soko-series-a block h-full rounded-full"
                  style={"width: #{day.share * 100}%"}
                >
                </span>
              </div>
              <p class="mt-1.5 text-xs tabular-nums text-soko-ink-2">{day.ctas} next steps</p>
            </li>
          </ol>
          <p :if={@overview.leaders == []} class="mt-3 text-sm text-soko-ink-2">
            No buyer messages in this range.
          </p>
        </section>
      </div>
    </section>
    """
  end

  defp spark_points(values) do
    max_value = values |> Enum.max() |> max(1)
    last = max(length(values) - 1, 1)

    values
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {value, index} ->
      x = index / last * 120
      y = 26 - value / max_value * 22
      "#{Float.round(x, 2)},#{Float.round(y, 2)}"
    end)
  end

  defp bar_pct(value, ceil) when ceil > 0, do: value / ceil * 100
  defp bar_pct(_value, _ceil), do: 0

  defp show_label?(_index, "week", _count), do: true
  defp show_label?(index, "month", count), do: rem(index, 5) == 0 or index == count - 1

  defp day_label(date), do: Calendar.strftime(date, "%-d")

  defp chart_label(days) do
    Enum.map_join(days, ", ", fn day ->
      "#{Calendar.strftime(day.date, "%b %-d")}: #{day.buyer} messages, #{day.ctas} CTAs"
    end)
  end
end
