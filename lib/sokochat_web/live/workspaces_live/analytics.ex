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
      current_user={@current_user}
      tab={:analytics}
      title="Analytics"
      flash={@flash}
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
    <section class="spot-overview" aria-label="Workspace analytics">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-3">
        <p class="text-[0.8125rem] text-n500">{@overview.caption}</p>
        <div
          class="inline-flex rounded-lg border border-n300 bg-n50 p-0.5"
          role="group"
          aria-label="Date range"
        >
          <button
            :for={{id, label} <- [{"week", "Week"}, {"month", "Month"}]}
            type="button"
            phx-click="set_range"
            phx-value-range={id}
            aria-pressed={to_string(@overview.range == id)}
            class={[
              "h-7 rounded-md px-2.5 text-[0.75rem]",
              @overview.range == id && "bg-primary text-white",
              @overview.range != id && "text-n500"
            ]}
          >
            {label}
          </button>
        </div>
      </div>

      <ul class="spot-kpis grid grid-cols-2 gap-2" aria-label="Key metrics">
        <li
          :for={kpi <- @overview.kpis}
          class="flex flex-col rounded-xl border border-n300 bg-n50 px-3.5 py-3"
        >
          <span class="text-[0.8125rem] text-n500">{kpi.label}</span>
          <div class="mt-2.5 flex items-center justify-between gap-2">
            <p class="text-[1.5rem] font-medium tabular-nums leading-none tracking-[-0.02em]">
              {kpi.value}
            </p>
            <span
              :if={kpi.delta}
              class={[
                "inline-flex h-5 items-center rounded-full px-1.5 text-[0.75rem] font-medium tabular-nums",
                kpi.delta > 0 && "bg-primary-light text-primary",
                kpi.delta < 0 && "bg-red-50 text-red-700"
              ]}
            >
              {if kpi.delta > 0, do: "+", else: "−"}{abs(kpi.delta)}%
            </span>
          </div>
          <svg
            :if={Enum.any?(kpi.spark, &(&1 > 0))}
            viewBox="0 0 120 28"
            class={[
              "mt-2 h-7 w-full",
              (is_nil(kpi.delta) or kpi.delta >= 0) && "text-series-views",
              kpi.delta && kpi.delta < 0 && "text-red-700"
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

      <div class="spot-overview-grid mt-2 grid gap-2">
        <section
          class="rounded-xl border border-n300 bg-n50 px-4 py-3.5"
          aria-labelledby="activity-chart"
        >
          <header class="mb-3 flex flex-wrap items-center justify-between gap-2">
            <h2 id="activity-chart" class="text-[0.875rem] font-medium tracking-[-0.02em]">
              Activity
            </h2>
            <ul class="flex flex-wrap justify-end gap-x-3 gap-y-1 text-[0.75rem] text-n500">
              <li class="inline-flex items-center gap-1.5">
                <i class="h-2 w-2 rounded-[2.5px] bg-series-views" aria-hidden="true"></i> Messages
              </li>
              <li class="inline-flex items-center gap-1.5">
                <i class="h-2 w-2 rounded-[2.5px] bg-series-clicks" aria-hidden="true"></i> CTAs
              </li>
            </ul>
          </header>
          <figure class="spot-chart" role="img" aria-label={chart_label(@overview.days)}>
            <div class="spot-chart-grid" aria-hidden="true">
              <span :for={tick <- @ticks} data-value={tick}></span>
            </div>
            <ol class="spot-chart-cols" style={"--cols: #{max(length(@overview.days), 1)}"}>
              <li :for={{day, index} <- Enum.with_index(@overview.days)} class="spot-chart-col">
                <div
                  class="spot-bars"
                  title={"#{day_label(day.date)} · #{day.buyer} messages · #{day.ctas} CTAs"}
                >
                  <span
                    class="spot-bar bg-series-views"
                    style={"height: #{bar_pct(day.buyer, @overview.ceil)}%"}
                  >
                  </span>
                  <span
                    class="spot-bar bg-series-clicks"
                    style={"height: #{bar_pct(day.ctas, @overview.ceil)}%"}
                  >
                  </span>
                </div>
                <span
                  class="spot-chart-label"
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

        <section
          class="rounded-xl border border-n300 bg-n50 px-4 py-3.5"
          aria-labelledby="busiest-days"
        >
          <h2 id="busiest-days" class="text-[0.875rem] font-medium tracking-[-0.02em]">
            Busiest days
          </h2>
          <ol :if={@overview.leaders != []} class="mt-3 space-y-3">
            <li :for={day <- @overview.leaders}>
              <div class="flex items-baseline justify-between gap-2">
                <span class="text-[0.875rem] font-medium">{day.label}</span>
                <span class="text-[0.75rem] tabular-nums text-n500">{day.buyer} messages</span>
              </div>
              <div class="mt-1.5 h-1 overflow-hidden rounded-full bg-n200" aria-hidden="true">
                <span
                  class="block h-full rounded-full bg-series-views"
                  style={"width: #{day.share * 100}%"}
                >
                </span>
              </div>
              <p class="mt-1.5 text-[0.75rem] tabular-nums text-n500">{day.ctas} CTAs</p>
            </li>
          </ol>
          <p :if={@overview.leaders == []} class="mt-3 text-[0.8125rem] text-n500">
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
