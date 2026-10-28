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
    this.el.addEventListener("click", async () => {
      let text = this.el.dataset.copy || ""

      if (text === "") return

      try {
        await navigator.clipboard.writeText(text)
      } catch (_error) {
        let textarea = document.createElement("textarea")
        textarea.value = text
        textarea.setAttribute("readonly", "")
        textarea.style.position = "absolute"
        textarea.style.left = "-9999px"
        document.body.appendChild(textarea)
        textarea.select()
        document.execCommand("copy")
        document.body.removeChild(textarea)
      }
    })
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

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
