defmodule WhatsappbotWeb.WorkspacesLive.Show do
  use WhatsappbotWeb, :live_view

  alias Whatsappbot.CTARules
  alias Whatsappbot.Endpoints
  alias Whatsappbot.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Workspace dashboard")}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        endpoint = Endpoints.get_endpoint(workspace.id)
        cta_rules = CTARules.list_cta_rules(workspace.id)

        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:endpoint_configured, configured?(endpoint, :endpoint))
         |> assign(:cta_rules_configured, configured?(cta_rules, :cta_rules))}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp configured?(%{url: url}, :endpoint), do: not is_nil_or_blank?(url)
  defp configured?(cta_rules, :cta_rules) when is_list(cta_rules), do: cta_rules != []
  defp configured?(workspace, :playground), do: not is_nil_or_blank?(workspace.ai_instructions)
  defp configured?(_resource, _section), do: false

  defp status_classes(true), do: "border-[#B7EBCF] bg-[#E8FFF3] text-brand-mid"
  defp status_classes(false), do: "border-[#FFD9A0] bg-[#FFF8ED] text-[#C77700]"

  defp status_label(true), do: "Configured"
  defp status_label(false), do: "Not configured"

  defp is_nil_or_blank?(value), do: is_nil(value) or String.trim(value) == ""

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :href, :string, required: true
  attr :cta, :string, required: true
  attr :configured, :boolean, required: true
  attr :highlight, :boolean, default: false

  defp section_card(assigns) do
    ~H"""
    <article class={[
      "flex flex-col rounded-xl border border-line bg-surface p-6 shadow-card",
      @highlight && "border-l-[3px] border-l-brand-light"
    ]}>
      <div class="flex items-start justify-between gap-4">
        <h2 class="text-[17px] font-semibold text-ink">{@title}</h2>
        <span class={[
          "shrink-0 rounded-full border px-2.5 py-0.5 text-[11px] font-semibold tracking-[0.3px]",
          status_classes(@configured)
        ]}>
          {status_label(@configured)}
        </span>
      </div>
      <p class="mt-1.5 line-clamp-2 text-sm leading-6 text-ink-muted">{@description}</p>
      <.link
        navigate={@href}
        class="group mt-6 inline-flex items-center gap-1 text-sm font-semibold text-brand-dark hover:underline"
      >
        {@cta}
        <span class="transition group-hover:translate-x-0.5">→</span>
      </.link>
    </article>
    """
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :configured_count,
        Enum.count(
          [
            assigns[:endpoint_configured],
            assigns[:cta_rules_configured],
            configured?(assigns[:workspace], :playground),
            false
          ],
          & &1
        )
      )

    ~H"""
    <section :if={assigns[:workspace]} class="space-y-8">
      <nav class="flex items-center gap-1.5 text-[13px] text-ink-faint">
        <.link navigate={~p"/workspaces"} class="transition hover:text-ink-muted">Workspaces</.link>
        <span>/</span>
        <span class="text-ink-muted">{@workspace.name}</span>
      </nav>

      <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div class="space-y-3">
          <div class="flex flex-wrap items-center gap-3">
            <h1 class="text-[30px] font-bold tracking-tight text-ink">{@workspace.name}</h1>
            <span class="rounded bg-surface-alt px-1.5 py-0.5 font-mono text-xs text-ink-faint">
              /{@workspace.slug}
            </span>
          </div>
          <p class="max-w-3xl text-[15px] leading-6 text-ink-muted">
            Configure your data, rules, playground, and WhatsApp connection.
          </p>
        </div>
        <.link
          navigate={~p"/workspaces/#{@workspace.id}/edit"}
          class="inline-flex items-center justify-center rounded-full border border-line bg-surface px-5 py-2 text-sm font-medium text-ink transition hover:bg-surface-alt"
        >
          Edit workspace
        </.link>
      </div>

      <div class="flex items-center gap-3">
        <div class="h-1 flex-1 overflow-hidden rounded-full bg-line">
          <div
            class="animate-progress h-full rounded-full bg-gradient-to-r from-brand-light to-brand-mid transition-[width] duration-500"
            style={"width: #{round(@configured_count / 4 * 100)}%"}
          >
          </div>
        </div>
        <span class="shrink-0 text-[13px] text-ink-muted">
          {@configured_count} of 4 steps complete
        </span>
      </div>

      <div class="grid gap-5 md:grid-cols-2">
        <.section_card
          title="Data Endpoint"
          description="Connect the JSON feed or API the bot should read from in real time."
          href={~p"/workspaces/#{@workspace.id}/endpoint"}
          cta="Open Data Endpoint"
          configured={@endpoint_configured}
        />
        <.section_card
          title="CTA Rules"
          description="Define which button, link, or list message should appear when a buyer is ready to act."
          href={~p"/workspaces/#{@workspace.id}/cta_rules"}
          cta="Open CTA Rules"
          configured={@cta_rules_configured}
        />
        <.section_card
          title="Playground"
          description="Test responses in a browser chat before connecting the workspace to a real WhatsApp number."
          href={~p"/workspaces/#{@workspace.id}/playground"}
          cta="Open Playground"
          configured={configured?(@workspace, :playground)}
          highlight
        />
        <.section_card
          title="Meta Connection"
          description="Connect Meta credentials and webhook settings when you are ready to go live."
          href={~p"/workspaces/#{@workspace.id}/meta"}
          cta="Open Meta Connection"
          configured={false}
        />
      </div>
    </section>
    """
  end
end
