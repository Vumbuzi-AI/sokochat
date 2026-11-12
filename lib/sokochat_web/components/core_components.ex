defmodule SokochatWeb.CoreComponents do
  @moduledoc """
  Sokochat v2 UI components.

  Each component mirrors a "Soko" component on the Doop canvas
  (https://doop.design/c/nbdU_ygDzg, Components page) and renders the
  matching `soko-*` classes from `assets/css/soko-components.css`.
  Colours, type and radii come from the tokens in `soko-tokens.css`.

  Icons are [Phosphor](https://phosphoricons.com) through
  `phosphor_live_view`. See `icon/1`.
  """
  use Phoenix.Component
  use Gettext, backend: SokochatWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders a Soko Modal on a flat scrim.

  The modal is server-driven: render it with `:if` and handle `on_close`
  to remove it. Body goes in the inner block; buttons go in `:actions`,
  secondary first. Forms inside the body can keep their own actions,
  which are styled as the modal footer.

  `tone="danger"` shows the red warning tile. Use it for destructive
  confirms together with a `tone="danger"` button labelled with the exact
  action.

  ## Examples

      <.modal :if={@show} id="new-product" title="New product" on_close="close_modal">
        ...
      </.modal>
  """
  attr :id, :string, default: "modal"
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :tone, :string, default: "default", values: ~w(default danger)
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :on_close, :any, default: "close_modal", doc: "event name or JS command"
  slot :inner_block
  slot :actions

  def modal(assigns) do
    ~H"""
    <div id={@id} class="fixed inset-0 z-50" phx-window-keydown={@on_close} phx-key="escape">
      <div class="soko-scrim" phx-click={@on_close} aria-hidden="true"></div>
      <div class="fixed inset-0 flex items-center justify-center p-4 pointer-events-none">
        <section
          class="soko-modal pointer-events-auto"
          data-tone={@tone}
          data-size={@size}
          role="dialog"
          aria-modal="true"
          aria-labelledby={"#{@id}-title"}
        >
          <header class="soko-modal-head">
            <span :if={@tone == "danger"} class="soko-modal-warn" aria-hidden="true">
              <.icon name="warning-circle" />
            </span>
            <div class="soko-modal-titles">
              <h2 id={"#{@id}-title"} class="soko-modal-title">{@title}</h2>
              <p :if={@text} class="soko-modal-text">{@text}</p>
            </div>
            <button
              type="button"
              class="soko-icon-btn"
              phx-click={@on_close}
              aria-label={gettext("Close")}
            >
              <.icon name="x" />
            </button>
          </header>
          <div class="soko-modal-body">{render_slot(@inner_block)}</div>
          <footer :if={@actions != []} class="soko-modal-foot">
            {render_slot(@actions)}
          </footer>
        </section>
      </div>
    </div>
    """
  end

  @doc """
  Renders a Soko Modal confirm on a native `<dialog>`. It opens on the
  client, so it works on LiveView and controller pages alike. Open it from
  any element with `data-dialog-open={id}`; Cancel and Escape close it.

  ## Examples

      <.icon_button icon="sign-out" data-dialog-open="logout" aria-label="Log out" />
      <.confirm_dialog id="logout" title="Log out of Sokochat?">
        <:actions>
          <.button href={~p"/users/log_out"} method="delete" tone="danger">Log out</.button>
        </:actions>
      </.confirm_dialog>
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :tone, :string, default: "danger", values: ~w(default danger)
  slot :actions, required: true

  def confirm_dialog(assigns) do
    ~H"""
    <dialog id={@id} class="soko-dialog" aria-labelledby={"#{@id}-title"} phx-update="ignore">
      <section class="soko-modal" data-tone={@tone} data-size="sm">
        <header class="soko-modal-head">
          <span :if={@tone == "danger"} class="soko-modal-warn" aria-hidden="true">
            <.icon name="warning-circle" />
          </span>
          <div class="soko-modal-titles">
            <h2 id={"#{@id}-title"} class="soko-modal-title">{@title}</h2>
            <p :if={@text} class="soko-modal-text">{@text}</p>
          </div>
          <button type="button" class="soko-icon-btn" data-dialog-close aria-label={gettext("Close")}>
            <.icon name="x" />
          </button>
        </header>
        <footer class="soko-modal-foot">
          <.button type="button" tone="secondary" data-dialog-close>{gettext("Cancel")}</.button>
          {render_slot(@actions)}
        </footer>
      </section>
    </dialog>
    """
  end

  @doc """
  Renders a flash message as a Soko Toast.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome back</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide_flash("##{@id}")}
      role="alert"
      class="soko-toast"
      data-tone={if @kind == :error, do: "danger", else: "success"}
      {@rest}
    >
      <span class="soko-toast-icon" aria-hidden="true">
        <.icon :if={@kind == :info} name="check-circle" weight="fill" />
        <.icon :if={@kind == :error} name="warning-circle" weight="fill" />
      </span>
      <span class="soko-toast-body">
        <span :if={@title} class="soko-toast-title">{@title}</span>
        <span>{msg}</span>
      </span>
      <button type="button" class="soko-toast-close" aria-label={gettext("Close")}>
        <.icon name="x" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="soko-toasts">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("You're offline")}
        phx-disconnected={show_flash(".phx-client-error #client-error")}
        phx-connected={hide_flash("#client-error")}
        hidden
      >
        {gettext("Reconnecting")}
        <.icon name="arrow-clockwise" class="soko-toast-spin h-3 w-3" />
      </.flash>
      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong")}
        phx-disconnected={show_flash(".phx-server-error #server-error")}
        phx-connected={hide_flash("#server-error")}
        hidden
      >
        {gettext("Getting back on track")}
        <.icon name="arrow-clockwise" class="soko-toast-spin h-3 w-3" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a form with Soko spacing. Actions sit at the end, right-aligned.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} class={["soko-form", @class]} {@rest}>
      {render_slot(@inner_block, f)}
      <div :for={action <- @actions} class="soko-form-actions">
        {render_slot(action, f)}
      </div>
    </.form>
    """
  end

  @doc """
  Renders a Soko Button. Pass `navigate`, `patch` or `href` to render a link
  with the same look.

    * `tone` - `primary` (forest, one per view), `secondary` (white fill and
      border), `dark` (marketing nav and pairs), `danger` (only for the
      confirm step of a destructive action).
    * `size` - `lg` (48, marketing and auth), `md` (40), `sm` (30, desk).
    * `width` - `full` for auth forms.

  ## Examples

      <.button>Save changes</.button>
      <.button tone="secondary" type="button" phx-click="close_modal">Cancel</.button>
      <.button navigate={~p"/users/register"} size="lg">List your shop</.button>
  """
  attr :tone, :string, default: "primary", values: ~w(primary secondary dark danger)
  attr :size, :string, default: "md", values: ~w(lg md sm)
  attr :width, :string, default: "auto", values: ~w(auto full)
  attr :type, :string, default: nil
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :href, :string, default: nil
  attr :method, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled form name value download target)

  slot :inner_block, required: true

  def button(%{navigate: nav, patch: patch, href: href} = assigns)
      when not is_nil(nav) or not is_nil(patch) or not is_nil(href) do
    ~H"""
    <.link
      navigate={@navigate}
      patch={@patch}
      href={@href}
      method={@method}
      class={["soko-btn", @class]}
      data-tone={@tone}
      data-size={@size}
      data-width={@width}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={["soko-btn", @class]}
      data-tone={@tone}
      data-size={@size}
      data-width={@width}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a quiet 30px icon button: modal close, row actions, log out.
  An `aria-label` is required.

  ## Examples

      <.icon_button icon="dots-three" aria-label="More" phx-click="menu" />
      <.icon_button icon="sign-out" tone="danger" aria-label="Log out" />
  """
  attr :icon, :string, required: true
  attr :tone, :string, default: "default", values: ~w(default danger)
  attr :type, :string, default: "button"
  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :method, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled aria-label title)

  def icon_button(%{navigate: nav, href: href} = assigns)
      when not is_nil(nav) or not is_nil(href) do
    ~H"""
    <.link
      navigate={@navigate}
      href={@href}
      method={@method}
      class={["soko-icon-btn", @class]}
      data-tone={@tone}
      {@rest}
    >
      <.icon name={@icon} />
    </.link>
    """
  end

  def icon_button(assigns) do
    ~H"""
    <button type={@type} class={["soko-icon-btn", @class]} data-tone={@tone} {@rest}>
      <.icon name={@icon} />
    </button>
    """
  end

  @doc """
  Renders a Soko Field (text inputs), Soko Select, textarea, Soko Checkbox
  or Soko Toggle, with label, hint and errors.

  A `Phoenix.HTML.FormField` may be passed as argument, which is used to
  retrieve the input name, id, and values. Otherwise all attributes may be
  passed explicitly.

    * `size` - `lg` (48, auth and marketing) or `md` (36, desk, the default).
    * `type="toggle"` renders a switch row with `label` and `hint`.
    * `:trailing` slot holds an icon at the end of the box, e.g. an eye
      toggle for passwords.

  ## Examples

      <.input field={@form[:email]} type="email" label="Email" size="lg" />
      <.input field={@form[:ai_enabled]} type="toggle" label="AI replies" />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :hint, :string, default: nil
  attr :value, :any
  attr :size, :string, default: "md", values: ~w(lg md)
  attr :class, :any, default: nil

  attr :type, :string,
    default: "text",
    values: ~w(checkbox toggle color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step inputmode)

  slot :trailing

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: type} = assigns) when type in ~w(checkbox toggle) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class={@class}>
      <label class={if @type == "toggle", do: "soko-toggle", else: "soko-check"}>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span :if={@type == "toggle"} class="soko-toggle-text">
          <span class="soko-toggle-label">{@label}</span>
          <span :if={@hint} class="soko-toggle-hint">{@hint}</span>
        </span>
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          role={@type == "toggle" && "switch"}
          {@rest}
        />
        <span :if={@type == "checkbox"}>{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class={["soko-field", @class]} data-size={@size} data-state={@errors != [] && "error"}>
      <.label :if={@label} for={@id}>
        {@label}
      </.label>
      <div class="soko-box">
        <select id={@id} name={@name} class="soko-control" multiple={@multiple} {@rest}>
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
        <.icon :if={!@multiple} name="caret-down" class="soko-caret" />
      </div>
      <p :if={@hint && @errors == []} class="soko-hint">{@hint}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class={["soko-field", @class]} data-size={@size} data-state={@errors != [] && "error"}>
      <.label :if={@label} for={@id}>
        {@label}
      </.label>
      <div class="soko-box">
        <textarea id={@id} name={@name} class="soko-control" {@rest}>{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </div>
      <p :if={@hint && @errors == []} class="soko-hint">{@hint}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class={["soko-field", @class]} data-size={@size} data-state={@errors != [] && "error"}>
      <.label :if={@label} for={@id}>
        {@label}
      </.label>
      <div class="soko-box">
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class="soko-control"
          aria-invalid={@errors != [] && "true"}
          {@rest}
        />
        <span :if={@trailing != []} class="soko-trailing">{render_slot(@trailing)}</span>
      </div>
      <p :if={@hint && @errors == []} class="soko-hint">{@hint}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a field label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="soko-label">{render_slot(@inner_block)}</label>
    """
  end

  @doc """
  Generates a field error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="soko-error">
      <.icon name="warning-circle" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a Soko Segmented control: two or three options on a stage track.
  It submits like a radio group.

  ## Examples

      <.segmented field={@form[:reply_mode]} options={[{"Send automatically", "auto"}, {"Approve first", "approve"}]} />
  """
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :name, :string, default: nil
  attr :value, :any, default: nil
  attr :options, :list, required: true, doc: "list of {label, value}"
  attr :label, :string, default: nil
  attr :rest, :global

  def segmented(assigns) do
    assigns =
      case assigns.field do
        %Phoenix.HTML.FormField{} = field ->
          assign(assigns, name: field.name, value: assigns.value || field.value)

        nil ->
          assigns
      end

    ~H"""
    <div class="soko-segmented" role="radiogroup" aria-label={@label} {@rest}>
      <label :for={{label, value} <- @options}>
        <input
          type="radio"
          name={@name}
          value={value}
          checked={to_string(@value) == to_string(value)}
        />
        {label}
      </label>
    </div>
    """
  end

  @doc """
  Renders the desk page title with an optional subtitle and actions
  (Soko Page Header). The desk shell renders one for every page; use this
  for headings inside a page.
  """
  attr :class, :any, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["soko-page-header", @class]}>
      <div class="soko-page-titles">
        <h1 class="soko-page-title">{render_slot(@inner_block)}</h1>
        <span :if={@subtitle != []} class="soko-page-subtitle">{render_slot(@subtitle)}</span>
      </div>
      <div :if={@actions != []} class="soko-page-actions">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a settings section: title and help on the left, fields on the
  right. Stack several inside one panel; dividers come for free.

  ## Examples

      <.section title="Business profile" text="Sokochat uses this to describe your shop.">
        <.input field={@form[:name]} label="Business name" />
      </.section>
  """
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <section class={["soko-section", @class]}>
      <div>
        <h2 class="soko-section-title">{@title}</h2>
        <p :if={@text} class="soko-section-text">{@text}</p>
      </div>
      <div class="flex min-w-0 flex-col gap-4">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  @doc """
  Renders a Soko Badge.

    * `success` - paid, active, connected
    * `waiting` - to confirm, draft ready
    * `neutral` - draft, hidden
    * `danger` - cancelled, failed
    * `dark` - counts on photos
  """
  attr :tone, :string, default: "success", values: ~w(success waiting neutral danger dark)
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={["soko-badge", @class]} data-tone={@tone}>{render_slot(@inner_block)}</span>
    """
  end

  @doc """
  Renders a Soko Avatar: a seeded orb, never initials. Pass any term as
  `seed` and the same person always gets the same orb.
  """
  attr :seed, :any, default: 1
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :label, :string, default: nil
  attr :class, :any, default: nil

  def avatar(assigns) do
    assigns = assign(assigns, :seed_index, seed_index(assigns.seed))

    ~H"""
    <span
      class={["soko-avatar", @class]}
      data-seed={@seed_index}
      data-size={@size}
      role={@label && "img"}
      aria-label={@label}
      aria-hidden={is_nil(@label) && "true"}
    >
    </span>
    """
  end

  defp seed_index(seed) when is_integer(seed) and seed in 1..6, do: seed
  defp seed_index(seed), do: :erlang.phash2(seed, 6) + 1

  @doc """
  Renders a Soko Banner: an inline message above a form or list.
  `danger` for form errors, `info` for neutral notices, `waiting` for
  things that need the merchant.
  """
  attr :tone, :string, default: "info", values: ~w(danger info waiting)
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def banner(assigns) do
    ~H"""
    <div class={["soko-banner", @class]} data-tone={@tone} role={@tone == "danger" && "alert"} {@rest}>
      <.icon name={if @tone == "info", do: "info", else: "warning-circle"} weight="fill" />
      <div class="min-w-0 flex-1">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  @doc """
  Renders a Soko Empty state. Centre it in the content panel.
  """
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :icon, :string, default: "package"
  attr :class, :any, default: nil
  slot :actions

  def empty(assigns) do
    ~H"""
    <div class={["soko-empty", @class]}>
      <span class="soko-empty-tile" aria-hidden="true"><.icon name={@icon} /></span>
      <p class="soko-empty-title">{@title}</p>
      <p :if={@text} class="soko-empty-text">{@text}</p>
      <div :if={@actions != []} class="soko-empty-actions">{render_slot(@actions)}</div>
    </div>
    """
  end

  @doc """
  Renders the mono "Sample data" tag. Every screen that shows invented
  data carries one.
  """
  attr :class, :any, default: nil

  def sample_tag(assigns) do
    ~H"""
    <span class={["soko-sample", @class]}>{gettext("Sample data")}</span>
    """
  end

  @doc """
  Renders a Soko Order Note, the floating card on marketing photos.
  """
  attr :photo, :string, required: true
  attr :title, :string, required: true
  attr :meta, :string, required: true
  attr :badge, :string, required: true
  attr :foot_left, :string, required: true
  attr :foot_right, :string, required: true
  attr :class, :any, default: nil

  def order_note(assigns) do
    ~H"""
    <article class={["soko-order-note", @class]}>
      <div class="soko-order-note-head">
        <img class="soko-order-note-thumb" src={@photo} alt="" />
        <span class="soko-order-note-text">
          <strong>{@title}</strong>
          <span>{@meta}</span>
        </span>
        <span class="soko-order-note-badge">{@badge}</span>
      </div>
      <p class="soko-order-note-foot">
        <span>{@foot_left}</span>
        <strong>{@foot_right}</strong>
      </p>
    </article>
    """
  end

  @doc """
  Renders a Soko Stat Note, the small floating stat on marketing photos.
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :caption, :string, required: true
  attr :class, :any, default: nil

  def stat_note(assigns) do
    ~H"""
    <article class={["soko-stat-note", @class]}>
      <span class="soko-stat-note-label">{@label}</span>
      <strong class="soko-stat-note-value">{@value}</strong>
      <span class="soko-stat-note-caption">{@caption}</span>
    </article>
    """
  end

  @doc """
  Renders a read-only value with a Copy button, for webhook URLs, tokens
  and buyer links.
  """
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  def copy_field(assigns) do
    ~H"""
    <div class="flex items-end gap-2">
      <.input
        id={@id}
        name={@id}
        type="text"
        readonly
        value={@value}
        label={@label}
        class="min-w-0 flex-1"
      />
      <.button
        id={"copy-#{@id}"}
        type="button"
        tone="secondary"
        phx-hook="ClipboardCopy"
        data-copy={@value}
        title="Copy"
      >
        <.icon name="copy" /> Copy
      </.button>
    </div>
    """
  end

  @doc """
  Renders one line of a setup checklist: a forest check when done, a
  dashed circle when not.
  """
  attr :done, :boolean, required: true
  attr :label, :string, required: true

  def checklist_item(assigns) do
    ~H"""
    <div class="flex items-center gap-2.5 text-sm">
      <.icon
        name={if @done, do: "check-circle", else: "circle-dashed"}
        weight={if @done, do: "fill", else: "regular"}
        class={["h-4 w-4 flex-none", (@done && "text-soko-forest") || "text-soko-ink-3"]}
      />
      <span class={(@done && "text-soko-ink") || "text-soko-ink-2"}>{@label}</span>
    </div>
    """
  end

  @doc ~S"""
  Renders a Soko table: 40px grey header, 52px rows.

  ## Examples

      <.table id="products" rows={@products}>
        <:col :let={product} label="Product">{product.name}</:col>
        <:col :let={product} label="From" align="right">{product.price}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
    attr :align, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="soko-table-wrap">
      <table class="soko-table">
        <thead>
          <tr>
            <th :for={col <- @col} class={col[:align] == "right" && "soko-num"}>{col[:label]}</th>
            <th :if={@action != []} class="w-12">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} data-clickable={@row_click && true}>
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={col[:align] == "right" && "soko-num"}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="soko-num">
              <div class="flex items-center justify-end gap-1">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="divide-y divide-soko-divider">
      <div :for={item <- @item} class="flex gap-4 py-3 text-sm sm:gap-8">
        <dt class="w-1/3 flex-none text-soko-ink-2">{item.title}</dt>
        <dd class="min-w-0 text-soko-ink">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/workspaces"}>Back to shops</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="inline-flex items-center gap-2 text-sm font-medium text-soko-ink-2 hover:text-soko-ink"
    >
      <.icon name="arrow-left" class="h-4 w-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a Phosphor icon. Regular weight by default; use `weight="fill"`
  for the active nav item and toast icons.

  Older `hero-*` names are kept as aliases so existing call sites keep
  working.

  ## Examples

      <.icon name="storefront" />
      <.icon name="house" weight="fill" class="h-4 w-4" />
  """
  attr :name, :string, required: true
  attr :weight, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  @icon_map %{
    "hero-arrow-left-solid" => "arrow-left",
    "hero-arrow-left-mini" => "arrow-left",
    "hero-arrow-path" => "arrow-clockwise",
    "hero-arrow-path-mini" => "arrow-clockwise",
    "hero-arrow-right-on-rectangle" => "sign-out",
    "hero-bars-3" => "list",
    "hero-bolt" => "lightning",
    "hero-bolt-mini" => "lightning",
    "hero-building-storefront" => "storefront",
    "hero-chart-bar" => "chart-bar",
    "hero-chat-bubble-left-right" => "chats",
    "hero-chat-bubble-left-right-mini" => "chats",
    "hero-check-badge-mini" => "seal-check",
    "hero-check-circle-mini" => "check-circle",
    "hero-code-bracket-mini" => "code",
    "hero-cursor-arrow-rays" => "cursor",
    "hero-cursor-arrow-rays-mini" => "cursor",
    "hero-document-duplicate-mini" => "copy",
    "hero-eye-slash-mini" => "eye-slash",
    "hero-exclamation-circle-mini" => "warning-circle",
    "hero-exclamation-triangle-mini" => "warning",
    "hero-globe-alt-mini" => "globe",
    "hero-information-circle-mini" => "info",
    "hero-list-bullet-mini" => "list-bullets",
    "hero-map-pin-mini" => "map-pin",
    "hero-minus-circle-mini" => "minus-circle",
    "hero-pencil-square-mini" => "pencil-simple",
    "hero-phone-mini" => "phone",
    "hero-photo" => "image",
    "hero-plus" => "plus",
    "hero-plus-mini" => "plus",
    "hero-shield-check-mini" => "shield-check",
    "hero-signal" => "broadcast",
    "hero-sparkles-mini" => "sparkle",
    "hero-squares-2x2" => "squares-four",
    "hero-squares-2x2-mini" => "squares-four",
    "hero-trash-mini" => "trash",
    "hero-wrench-screwdriver" => "wrench",
    "hero-x-mark" => "x",
    "hero-x-mark-mini" => "x",
    "hero-x-mark-solid" => "x"
  }

  def icon(assigns) do
    assigns =
      assign(assigns,
        phosphor_name: Map.get(@icon_map, assigns.name, assigns.name),
        phosphor_weight: assigns.weight || "regular",
        class: icon_class(assigns.class)
      )

    ~H"""
    <Phosphor.icon name={@phosphor_name} weight={@phosphor_weight} class={@class} {@rest} />
    """
  end

  defp icon_class(class) when is_list(class) do
    case class |> List.flatten() |> Enum.filter(&is_binary/1) do
      [] -> nil
      classes -> Enum.join(classes, " ")
    end
  end

  defp icon_class(class) when is_binary(class), do: class
  defp icon_class(_class), do: nil

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-out duration-200", "opacity-0 translate-y-2",
         "opacity-100 translate-y-0"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 150,
      transition:
        {"transition-all ease-in duration-150", "opacity-100 translate-y-0",
         "opacity-0 translate-y-2"}
    )
  end

  defp show_flash(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition: {"soko-toast-enter", "soko-toast-enter-from", "soko-toast-enter-to"}
    )
  end

  defp hide_flash(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 150,
      transition: {"soko-toast-leave", "soko-toast-leave-from", "soko-toast-leave-to"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(SokochatWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(SokochatWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
