defmodule SokochatWeb.LegalLive do
  use SokochatWeb, :live_view
  alias SokochatWeb.{HomeLive.Components, LegalCopy, MarketingComponents}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, marketing: true, legal_draft: true), layout: false}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    document = LegalCopy.fetch!(socket.assigns.live_action)
    other = if socket.assigns.live_action == :privacy, do: :terms, else: :privacy

    {:noreply,
     socket
     |> assign(:document, document)
     |> assign(:page_title, document.title)
     |> assign(:other_document, LegalCopy.fetch!(other))
     |> assign(:other, other)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="top" class="soko-public-page">
      <a class="soko-skip-link" href="#legal-content">Skip to document</a>
      <Components.nav current_user={@current_user} />
      <main>
        <header class="legal-top">
          <p class="label">Trust &amp; transparency</p>
          <h1>{@document.title}</h1>
          <p class="intro">{@document.intro}</p>
          <div class="legal-meta">
            <span>Example draft</span>
            <span>Prepared <time datetime="2026-11-13">13 November 2026</time></span>
          </div>
        </header>
        <div class="legal-grid">
          <aside class="legal-toc">
            <div class="legal-toc-desktop">
              <p class="legal-toc-label">On this page</p>
              <.contents sections={@document.sections} label="Document contents" />
            </div>
            <details class="legal-toc-mobile">
              <summary>On this page</summary>
              <.contents sections={@document.sections} label="Document contents" />
            </details>
          </aside>
          <article id="legal-content" class="legal-copy" tabindex="-1" aria-label={@document.title}>
            <p class="legal-summary">{@document.summary}</p>
            <section
              :for={{section, index} <- Enum.with_index(@document.sections, 1)}
              id={section.id}
              class="legal-section"
              aria-labelledby={section.id <> "-title"}
            >
              <h2 id={section.id <> "-title"}>{number(index)} · {section.title}</h2>
              <p :for={paragraph <- section.paragraphs}>{paragraph}</p>
              <a :if={Map.has_key?(section, :link)} href={section[:link] && section.link.href}>
                {section[:link] && section.link.label}
              </a>
            </section>
            <aside class="legal-draft" aria-label="Draft status">
              Example content for review. Confirm the operator, contact details and final policy before publication.
            </aside>
            <nav class="legal-other" aria-label="More from Sokochat">
              <.link navigate={~p"/"}>Back to Sokochat</.link>
              <.link navigate={if @other == :terms, do: ~p"/terms", else: ~p"/privacy"}>
                {@other_document.title} <.icon name="arrow-up-right" class="h-3.5 w-3.5" />
              </.link>
            </nav>
          </article>
        </div>
      </main>
      <MarketingComponents.footer current_user={@current_user} />
    </div>
    """
  end

  attr :sections, :list, required: true
  attr :label, :string, required: true

  defp contents(assigns) do
    ~H"""
    <nav aria-label={@label}>
      <a :for={{section, index} <- Enum.with_index(@sections, 1)} href={"#" <> section.id}>
        <span>{number(index)}</span><span>{section.title}</span>
      </a>
    </nav>
    """
  end

  defp number(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")
end
