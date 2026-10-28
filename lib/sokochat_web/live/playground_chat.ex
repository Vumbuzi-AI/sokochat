defmodule SokochatWeb.PlaygroundChat do
  @moduledoc """
  Shared, presentational components for rendering the WhatsApp-style playground
  chat feed. These are pure function components: interactive elements emit
  `phx-click`/`phx-submit` events that are handled by whichever LiveView mounts
  them (the standalone `PlaygroundLive` or the unified `WorkspacesLive.Setup`).
  """
  use SokochatWeb, :html

  attr :message, :map, required: true
  attr :assistant_pending, :boolean, default: false

  def message_bubble(assigns) do
    assigns = assign(assigns, :outgoing, assigns.message.role == "user")

    ~H"""
    <div class={["wa-turn", @outgoing && "wa-turn-out"]}>
      <div class={["wa-bubble", @outgoing && "wa-outgoing", not @outgoing && "wa-incoming"]}>
        <span class="wa-copy">{@message.content}</span>
        <span class="wa-meta">
          {message_time(@message.inserted_at)}
          <.wa_glyph :if={@outgoing} name="read" />
        </span>
      </div>
      <.cta_block
        :if={@message.role == "assistant" && @message.cta}
        cta={@message.cta}
        assistant_pending={@assistant_pending}
      />
    </div>
    """
  end

  attr :name, :string, required: true

  def wa_glyph(assigns) do
    assigns = assign(assigns, :d, glyph_path(assigns.name))

    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d={@d} />
    </svg>
    """
  end

  attr :cta, :map, required: true
  attr :assistant_pending, :boolean, default: false

  def cta_block(assigns) do
    assigns =
      assigns
      |> assign(:type, cta_type(assigns.cta))
      |> assign(:payload, cta_payload(assigns.cta))

    ~H"""
    <div class="wa-cta">
      <div
        :if={@type in ["website", "phone", "whatsapp"] or cta_preview?(@type, @payload)}
        class="wa-catalog-message"
      >
        <div :if={payload_value(@payload, "image_url")} class="wa-product-photo">
          <img
            src={payload_value(@payload, "image_url")}
            alt={payload_value(@payload, "title") || ""}
          />
        </div>
        <div
          :if={payload_value(@payload, "title") || payload_value(@payload, "body")}
          class="wa-product-info"
        >
          <strong :if={payload_value(@payload, "title")}>{payload_value(@payload, "title")}</strong>
          <span :if={payload_value(@payload, "body")} class="wa-product-price">
            {payload_value(@payload, "body")}
          </span>
        </div>
        <a
          :if={@type == "website"}
          href={payload_value(@payload, "url")}
          target="_blank"
          rel="noreferrer"
          class="catalog-action"
        >
          <.wa_glyph name="bag" /> View catalog
        </a>
        <a
          :if={@type == "phone"}
          href={"tel:#{payload_value(@payload, "number")}"}
          class="catalog-action"
        >
          <.wa_glyph name="phone" /> Call {payload_value(@payload, "number")}
        </a>
        <a
          :if={@type == "whatsapp"}
          href={"https://wa.me/#{digits_only(payload_value(@payload, "number"))}"}
          target="_blank"
          rel="noreferrer"
          class="catalog-action"
        >
          <.wa_glyph name="phone" /> WhatsApp
        </a>
      </div>

      <div :if={@type == "reply_buttons"} class="wa-replies">
        <button
          :for={button <- payload_buttons(@payload)}
          id={"reply-button-#{slugify_value(button)}"}
          type="button"
          phx-click="send_interactive_message"
          phx-value-message={cta_prompt(button)}
          disabled={@assistant_pending}
          class="catalog-action"
        >
          {button}
        </button>
      </div>

      <div :if={@type == "list_message"} class="wa-replies">
        <button
          :for={item <- payload_items(@payload)}
          id={"list-item-#{slugify_value(payload_value(item, "title"))}"}
          type="button"
          phx-click="send_interactive_message"
          phx-value-message={cta_prompt(item)}
          disabled={@assistant_pending}
          class="wa-list-item"
        >
          <strong>{payload_value(item, "title")}</strong>
          <span>{payload_value(item, "description")}</span>
        </button>
      </div>

      <div :if={@type == "location"} class="wa-replies">
        <p class="wa-note">
          {payload_value(@payload, "latitude")}, {payload_value(@payload, "longitude")}
        </p>
      </div>

      <p :if={@type == "custom"} class="wa-replies wa-note">{payload_value(@payload, "template")}</p>

      <p :if={@type == "catalog"} class="wa-replies wa-note">
        {payload_value(@payload, "product_id")}
      </p>
    </div>
    """
  end

  @doc "Typing indicator bubble shown while the assistant is generating a reply."
  def typing_indicator(assigns) do
    ~H"""
    <div class="mt-2.5 flex justify-start animate-bubble-in">
      <div class="max-w-[85%] rounded-[12px_12px_12px_0] bg-n50 border border-n100 px-3.5 py-3 text-n900 shadow-[0_1px_2px_rgba(0,0,0,0.08)]">
        <div class="flex items-center gap-2 text-sm text-n400">
          <span class="flex items-center gap-1" aria-hidden="true">
            <span class="h-2 w-2 rounded-full bg-primary animate-pulse-dot"></span>
            <span class="h-2 w-2 rounded-full bg-primary animate-pulse-dot"></span>
            <span class="h-2 w-2 rounded-full bg-primary animate-pulse-dot"></span>
          </span>
          <span>Bot is typing...</span>
        </div>
      </div>
    </div>
    """
  end

  # --- pure helpers -------------------------------------------------------

  def cta_type(cta), do: payload_value(cta, "type")
  def cta_payload(cta), do: payload_value(cta, "payload") || %{}

  def payload_buttons(payload) do
    case payload_value(payload, "buttons") do
      buttons when is_list(buttons) -> buttons
      _ -> []
    end
  end

  def payload_items(payload) do
    case payload_value(payload, "items") do
      items when is_list(items) -> items
      _ -> []
    end
  end

  def cta_prompt(value) when is_binary(value), do: String.trim(value)

  def cta_prompt(item) when is_map(item) do
    item
    |> payload_value("title")
    |> cta_prompt()
  end

  def cta_prompt(_value), do: ""

  def slugify_value(nil), do: "option"

  def slugify_value(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "option"
      slug -> slug
    end
  end

  def payload_value(map, key) when is_map(map) do
    Map.get(map, key) ||
      case safe_existing_atom(key) do
        nil -> nil
        atom_key -> Map.get(map, atom_key)
      end
  rescue
    ArgumentError -> Map.get(map, key)
  end

  def payload_value(_value, _key), do: nil

  def cta_preview?(type, _payload) when type in ["reply_buttons", "list_message"], do: false

  def cta_preview?(_type, payload) do
    payload_value(payload, "image_url") || payload_value(payload, "title") ||
      payload_value(payload, "body")
  end

  defp safe_existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp glyph_path("microphone"),
    do: "M9 5a3 3 0 0 1 6 0v8a3 3 0 0 1-6 0Zm-3 7v1a6 6 0 0 0 12 0v-1M12 19v3"

  defp glyph_path("bag"), do: "M5 7h14l1 14H4ZM8 8V6a4 4 0 0 1 8 0v2"

  defp glyph_path("phone"),
    do:
      "M5.8 3.3c.5-.5 1.3-.5 1.7.1l2.4 3.7c.3.5.3 1.1-.1 1.5l-1.4 1.7c1.1 2.3 2.9 4.1 5.3 5.3l1.7-1.5c.4-.3 1-.4 1.5-.1l3.7 2.4c.6.4.7 1.2.2 1.7l-1.8 2c-.7.8-1.8 1.1-2.8.8-6.6-2.1-11.6-7.1-13.7-13.7-.3-1 .1-2.1.8-2.8Z"

  defp glyph_path("read"), do: "m2 12 4 4L16 6m-4 9 2 2L24 7"
  defp glyph_path(_name), do: "m5 12 4 4L19 6"

  def digits_only(nil), do: ""
  def digits_only(value), do: Regex.replace(~r/[^\d]/, to_string(value), "")

  def message_time(nil), do: ""
  def message_time(datetime), do: Calendar.strftime(datetime, "%H:%M")
end
