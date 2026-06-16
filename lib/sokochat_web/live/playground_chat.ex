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
    ~H"""
    <div class={[
      "animate-bubble-in flex",
      @message.role == "user" && "justify-end",
      @message.role != "user" && "justify-start"
    ]}>
      <div class={[
        "space-y-2",
        @message.role == "user" && "max-w-[80%]",
        @message.role != "user" && "max-w-[85%]"
      ]}>
        <div class={[
          "px-3.5 py-2.5 text-sm",
          @message.role == "user" && "rounded-[12px_12px_0_12px] bg-primary text-n50",
          @message.role != "user" &&
            "rounded-[12px_12px_12px_0] bg-n50 border border-n100 text-n800 shadow-[0_1px_2px_rgba(0,0,0,0.08)]"
        ]}>
          <p class="whitespace-pre-wrap break-words leading-6">{@message.content}</p>
          <.cta_block
            :if={@message.role == "assistant" && @message.cta}
            cta={@message.cta}
            assistant_pending={@assistant_pending}
          />
          <div class={[
            "mt-1 flex items-center justify-end gap-2 text-[11px]",
            @message.role == "user" && "text-n50/70",
            @message.role != "user" && "text-n400"
          ]}>
            <button
              :if={@message.role == "assistant"}
              id={"copy-reply-#{@message.id}"}
              type="button"
              phx-hook="ClipboardCopy"
              data-copy={@message.content}
              class="inline-flex items-center rounded-full p-1 text-n400 transition hover:bg-n200 hover:text-n900"
              title="Copy last reply"
            >
              <.icon name="hero-document-duplicate-mini" class="h-4 w-4" />
            </button>
            <span>{message_time(@message.inserted_at)}</span>
            <span :if={@message.role == "user"} class="text-n50/70" aria-hidden="true">✓✓</span>
          </div>
        </div>
      </div>
    </div>
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
    <div class="mt-2 space-y-2 border-t border-n200 pt-2">
      <div
        :if={cta_preview?(@type, @payload)}
        class="overflow-hidden rounded-[10px] border border-n200 bg-n50"
      >
        <img
          :if={payload_value(@payload, "image_url")}
          src={payload_value(@payload, "image_url")}
          alt={payload_value(@payload, "title") || "Product image"}
          class="aspect-video w-full object-cover"
        />
        <div class="space-y-0.5 px-3 py-2.5">
          <p :if={payload_value(@payload, "title")} class="text-sm font-semibold text-n900">
            {payload_value(@payload, "title")}
          </p>
          <p :if={payload_value(@payload, "body")} class="text-[13px] text-n400">
            {payload_value(@payload, "body")}
          </p>
        </div>
      </div>

      <a
        :if={@type == "website"}
        href={payload_value(@payload, "url")}
        target="_blank"
        rel="noreferrer"
        class="flex items-center justify-between rounded-lg border border-n200 bg-n50 px-4 py-2.5 text-sm font-medium text-primary transition hover:border-primary hover:bg-primary-light"
      >
        <span class="inline-flex items-center gap-2">
          <.icon name="hero-link-mini" class="h-4 w-4" /> Open link
        </span>
        <span class="truncate text-xs text-n500">{payload_value(@payload, "url")}</span>
      </a>

      <a
        :if={@type == "phone"}
        href={"tel:#{payload_value(@payload, "number")}"}
        class="inline-flex items-center gap-2 rounded-lg bg-[#25D366] px-3 py-2 text-sm font-semibold text-white transition hover:bg-[#1faa54]"
      >
        <.icon name="hero-phone-mini" class="h-4 w-4" /> Call {payload_value(@payload, "number")}
      </a>

      <a
        :if={@type == "whatsapp"}
        href={"https://wa.me/#{digits_only(payload_value(@payload, "number"))}"}
        target="_blank"
        rel="noreferrer"
        class="inline-flex items-center gap-2 rounded-lg bg-[#25D366] px-3 py-2 text-sm font-semibold text-white transition hover:bg-[#1faa54]"
      >
        <.icon name="hero-chat-bubble-left-right-mini" class="h-4 w-4" /> Message on WhatsApp
      </a>

      <div
        :if={@type == "reply_buttons"}
        class="overflow-hidden rounded-lg border border-n200 bg-n100"
      >
        <div class="border-b border-n200 px-3 py-2.5">
          <p class="text-sm font-semibold text-n900">
            {payload_value(@payload, "title") || "Quick replies"}
          </p>
          <p class="mt-0.5 text-xs text-n400">
            {payload_value(@payload, "body") || "Tap an option to send it instantly."}
          </p>
        </div>
        <div class="space-y-1.5 px-3 py-3">
          <button
            :for={button <- payload_buttons(@payload)}
            id={"reply-button-#{slugify_value(button)}"}
            type="button"
            phx-click="send_interactive_message"
            phx-value-message={cta_prompt(button)}
            disabled={@assistant_pending}
            class="w-full rounded-lg border border-n200 bg-n50 px-4 py-2.5 text-center text-sm font-medium text-primary transition hover:border-primary hover:bg-primary-light disabled:cursor-not-allowed disabled:opacity-60"
          >
            {button}
          </button>
        </div>
      </div>

      <div
        :if={@type == "list_message"}
        class="overflow-hidden rounded-lg border border-n200 bg-n100"
      >
        <div class="border-b border-n200 px-3 py-2.5">
          <p class="text-sm font-semibold text-n900">
            {payload_value(@payload, "title") || "Browse options"}
          </p>
          <p class="mt-0.5 text-xs text-n400">
            {payload_value(@payload, "body") || "Tap an option to send it like a WhatsApp selection."}
          </p>
        </div>
        <div class="space-y-2 px-3 py-3">
          <button
            :for={item <- payload_items(@payload)}
            id={"list-item-#{slugify_value(payload_value(item, "title"))}"}
            type="button"
            phx-click="send_interactive_message"
            phx-value-message={cta_prompt(item)}
            disabled={@assistant_pending}
            class="block w-full rounded-lg bg-n50 px-3 py-2 text-left shadow-[0_1px_1px_rgba(17,27,33,0.08)] transition hover:ring-2 hover:ring-primary/60 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <p class="text-sm font-semibold text-n900">{payload_value(item, "title")}</p>
            <p class="mt-1 text-xs text-n400">{payload_value(item, "description")}</p>
          </button>
        </div>
      </div>

      <div
        :if={@type == "location"}
        class="rounded-lg border border-n200 bg-n100 px-3 py-2 text-sm text-n900"
      >
        <div class="flex items-center gap-2 font-semibold">
          <.icon name="hero-map-pin-mini" class="h-4 w-4 text-primary" /> Location pin
        </div>
        <p class="mt-1 text-xs text-n400">
          {payload_value(@payload, "latitude")}, {payload_value(@payload, "longitude")}
        </p>
      </div>

      <p
        :if={@type == "custom"}
        class="rounded-lg bg-n100 px-3 py-2 text-sm italic text-n500"
      >
        {payload_value(@payload, "template")}
      </p>

      <p :if={@type == "catalog"} class="rounded-lg bg-n100 px-3 py-2 text-sm text-n900">
        Catalog item: <span class="font-semibold">{payload_value(@payload, "product_id")}</span>
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

  def digits_only(nil), do: ""
  def digits_only(value), do: Regex.replace(~r/[^\d]/, to_string(value), "")

  def message_time(nil), do: ""
  def message_time(datetime), do: Calendar.strftime(datetime, "%H:%M")
end
