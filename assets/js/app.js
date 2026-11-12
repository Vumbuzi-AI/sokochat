// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import {DashboardShell} from "./dashboard-shell.js"

let Hooks = {}

Hooks.ClipboardCopy = {
  mounted() {
    this.copyButton = this.el.matches("button") ? this.el : this.el.querySelector("[data-copy-button]")
    this.copying = false
    this.copiedValue = null
    this.copyError = false
    this.copyText = this.el.dataset.copy
    this.onCopy = async () => {
      let text = this.el.dataset.copy || ""

      if (text === "" || this.copying) return

      window.clearTimeout(this.copyTimer)
      this.copying = true
      this.copyError = false
      this.renderCopyFeedback()
      let copied = false

      try {
        await navigator.clipboard.writeText(text)
        copied = true
      } catch (_error) {
        if (!this.el.isConnected) return
        let textarea = document.createElement("textarea")
        let focused = document.activeElement

        try {
          textarea.value = text
          textarea.setAttribute("readonly", "")
          textarea.style.position = "fixed"
          textarea.style.left = "-9999px"
          document.body.appendChild(textarea)
          textarea.select()
          copied = document.execCommand("copy")
        } catch (_fallbackError) {
          copied = false
        } finally {
          textarea.remove()
          if (focused?.isConnected) focused.focus({preventScroll: true})
        }
      }

      this.copying = false
      if (!this.el.isConnected) return
      if (text !== this.el.dataset.copy) {
        this.renderCopyFeedback()
        return
      }

      this.copiedValue = copied ? text : null
      this.copyError = !copied
      this.renderCopyFeedback()

      if (copied) {
        this.copyTimer = window.setTimeout(() => {
          this.copiedValue = null
          this.renderCopyFeedback()
        }, 2000)
      } else {
        let input = this.el.closest("[data-copy-field]")?.querySelector("input")
        input?.focus({preventScroll: true})
        input?.select()
      }
    }
    this.copyButton.addEventListener("click", this.onCopy)
    this.renderCopyFeedback()
  },
  updated() {
    if (this.copyText !== this.el.dataset.copy) {
      window.clearTimeout(this.copyTimer)
      this.copyText = this.el.dataset.copy
      this.copiedValue = null
      this.copyError = false
    }
    this.renderCopyFeedback()
  },
  destroyed() {
    window.clearTimeout(this.copyTimer)
    this.copyButton.removeEventListener("click", this.onCopy)
  },
  renderCopyFeedback() {
    this.copyButton.disabled = this.copying
    let field = this.el.closest("[data-copy-field]")
    if (!field) return

    let copied = this.copiedValue === this.el.dataset.copy
    let input = field.querySelector("input")
    let status = field.querySelector("[data-copy-status]")
    let error = field.querySelector("[data-copy-error]")

    if (copied && document.activeElement === this.copyButton) input?.focus({preventScroll: true})
    this.copyButton.style.display = copied ? "none" : ""
    if (input) input.style.paddingRight = copied ? "5rem" : ""
    if (status) status.textContent = copied ? "Copied" : ""
    if (error) {
      error.hidden = !this.copyError
      error.textContent = this.copyError ? "Couldn't copy. Select the text and copy it manually." : ""
    }
  }
}

Hooks.TokenCounter = {
  updated() {
    if (this.el.textContent === this.lastValue) return
    this.lastValue = this.el.textContent
    this.el.style.animation = "none"
    // force reflow so the animation restarts
    void this.el.offsetWidth
    this.el.style.animation = "token-pop 300ms cubic-bezier(0.4, 0, 0.2, 1)"
  },
  mounted() {
    this.lastValue = this.el.textContent
  }
}

Hooks.PlaygroundScroll = {
  mounted() {
    this.lastSignature = this.signature()
    this.handleEvent("playground:scroll-bottom", () => this.scrollToBottom())
    window.requestAnimationFrame(() => this.scrollToBottom("auto"))
  },
  updated() {
    let nextSignature = this.signature()

    if (nextSignature === this.lastSignature) return

    this.lastSignature = nextSignature
    window.requestAnimationFrame(() => this.scrollToBottom())
  },
  signature() {
    return `${this.el.dataset.messageCount || "0"}:${this.el.dataset.pending || "false"}`
  },
  scrollToBottom(behavior) {
    this.el.scrollTo({
      top: this.el.scrollHeight,
      behavior: behavior || this.scrollBehavior()
    })
  },
  scrollBehavior() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth"
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
Hooks.DashboardShell = DashboardShell

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

document.addEventListener("phx:push", (event) => {
  const button = event.target
  if (!(button instanceof HTMLButtonElement)) return

  button.setAttribute("aria-busy", "true")
  const done = event.detail && event.detail.loadingComplete
  if (done && typeof done.then === "function") {
    done.finally(() => button.removeAttribute("aria-busy"))
  }
})

document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-password-toggle]")
  if (!button) return

  const input = document.getElementById(button.getAttribute("aria-controls"))
  if (!input) return

  const showing = input.type === "password"
  input.type = showing ? "text" : "password"
  button.setAttribute("aria-pressed", showing ? "true" : "false")
  button.setAttribute("aria-label", showing ? "Hide password" : "Show password")
  button.querySelector("[data-icon='show']")?.classList.toggle("hidden", !showing)
  button.querySelector("[data-icon='hide']")?.classList.toggle("hidden", showing)
  input.focus()
})

document.addEventListener("click", (event) => {
  const opener = event.target.closest?.("[data-dialog-open]")
  if (opener) {
    const dialog = document.getElementById(opener.dataset.dialogOpen)
    if (dialog && !dialog.open) dialog.showModal()
    return
  }

  if (event.target.closest?.("[data-dialog-close]")) {
    event.target.closest("dialog")?.close()
    return
  }

  if (event.target instanceof HTMLDialogElement && event.target.classList.contains("soko-dialog")) {
    event.target.close()
  }
})

const APPEARANCE_KEY = "soko-appearance"
const darkQuery = window.matchMedia("(prefers-color-scheme: dark)")

function readAppearance() {
  try {
    return window.localStorage.getItem(APPEARANCE_KEY) || "system"
  } catch {
    return "system"
  }
}

function applyAppearance(choice = readAppearance()) {
  const root = document.documentElement
  if (root.hasAttribute("data-marketing")) return
  const dark = choice === "dark" || (choice === "system" && darkQuery.matches)
  if (dark) root.setAttribute("data-theme", "dark")
  else root.removeAttribute("data-theme")
}

function syncAppearanceControls() {
  const choice = readAppearance()
  document.querySelectorAll("[data-appearance] input[name='appearance']").forEach((input) => {
    input.checked = input.value === choice
  })
}

darkQuery.addEventListener("change", () => applyAppearance())

document.addEventListener("change", (event) => {
  const input = event.target.closest?.("[data-appearance] input[name='appearance']")
  if (!input) return
  try {
    window.localStorage.setItem(APPEARANCE_KEY, input.value)
  } catch {
    // Private mode can reject storage. The choice still applies to this page.
  }
  applyAppearance(input.value)
})

window.addEventListener("phx:page-loading-stop", syncAppearanceControls)
document.addEventListener("DOMContentLoaded", syncAppearanceControls)

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
