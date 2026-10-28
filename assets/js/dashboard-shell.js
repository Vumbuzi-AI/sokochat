const STORAGE_FALLBACK = "sokochat-dashboard-sidebar-width"
const NAV_KEY = "sokochat-dashboard-nav"
const DOCKED_WIDTH = 672

function readNumber(key, fallback) {
  try {
    const value = Number(window.localStorage.getItem(key))
    return Number.isFinite(value) && value > 0 ? value : fallback
  } catch {
    return fallback
  }
}

function writeNumber(key, value) {
  try {
    window.localStorage.setItem(key, String(value))
  } catch {
    // Private mode can reject storage. The width still applies for this view.
  }
}

function readNav() {
  try {
    return window.sessionStorage.getItem(NAV_KEY)
  } catch {
    return null
  }
}

function writeNav(id) {
  if (!id) return
  try {
    window.sessionStorage.setItem(NAV_KEY, id)
  } catch {
    // Ignore storage failures.
  }
}

function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}

function offsetWithin(element, ancestor) {
  let top = 0
  let left = 0
  let node = element

  while (node && node !== ancestor) {
    top += node.offsetTop
    left += node.offsetLeft
    node = node.offsetParent
  }

  return {top, left}
}

function focusable(container) {
  return [
    ...container.querySelectorAll(
      'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])'
    ),
  ].filter((element) => element.getClientRects().length > 0)
}

export const DashboardShell = {
  mounted() {
    this.storageKey = this.el.dataset.storageKey || STORAGE_FALLBACK
    this.defaultWidth = Number(this.el.dataset.defaultWidth) || 200
    this.minWidth = Number(this.el.dataset.minWidth) || 180
    this.maxWidth = Number(this.el.dataset.maxWidth) || 400
    this.width = this.clamp(readNumber(this.storageKey, this.defaultWidth))
    this.dragging = false
    this.drawerOpen = false
    this.hoverList = null
    this.hoverShown = false
    this.hoverHiddenAt = 0
    this.closeTimer = null

    this.onPointerDown = (event) => {
      const handle = event.target.closest?.("[data-resize]")
      if (!handle || !this.el.contains(handle) || event.button !== 0) return
      event.preventDefault()
      this.dragging = true
      this.dragStartX = event.clientX
      this.dragOrigin = this.width
      try {
        handle.setPointerCapture(event.pointerId)
      } catch {
        // Capture is a convenience. Window listeners still track the drag.
      }
      this.el.setAttribute("data-resizing", "")
    }

    this.onPointerMove = (event) => {
      if (!this.dragging) return
      this.setWidth(this.dragOrigin + event.clientX - this.dragStartX)
    }

    this.onPointerUp = (event) => {
      if (!this.dragging) return
      this.dragging = false
      this.el.removeAttribute("data-resizing")
      const handle = this.el.querySelector("[data-resize]")
      if (handle?.hasPointerCapture?.(event.pointerId)) {
        handle.releasePointerCapture(event.pointerId)
      }
      writeNumber(this.storageKey, this.width)
    }

    this.onClick = (event) => {
      if (event.target.closest?.("[data-resize]")) {
        if (event.detail === 2) {
          this.setWidth(this.defaultWidth)
          writeNumber(this.storageKey, this.width)
        }
        return
      }

      if (event.target.closest?.("[data-menu]")) {
        event.preventDefault()
        this.openDrawer()
        return
      }

      if (event.target.closest?.("[data-drawer-backdrop], [data-drawer-close]")) {
        event.preventDefault()
        this.closeDrawer(true)
        return
      }

      if (event.target.closest?.("[data-drawer] [data-nav-item]")) {
        this.closeDrawer(false)
      }
    }

    this.onKeyDown = (event) => {
      const handle = event.target.closest?.("[data-resize]")
      if (handle && this.el.contains(handle)) {
        const next = {
          ArrowLeft: this.width - 10,
          ArrowRight: this.width + 10,
          Home: this.minWidth,
          End: this.maxWidth,
        }
        if (!(event.key in next)) return
        event.preventDefault()
        this.setWidth(next[event.key])
        writeNumber(this.storageKey, this.width)
        return
      }

      if (!this.drawerOpen) return

      if (event.key === "Escape") {
        event.preventDefault()
        event.stopPropagation()
        this.closeDrawer(true)
        return
      }

      if (event.key !== "Tab") return
      const drawer = this.el.querySelector("[data-drawer]")
      if (!drawer) return
      const items = focusable(drawer)
      const first = items[0]
      const last = items[items.length - 1]
      if (!first || !last) return

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      }
    }

    this.onPointerOver = (event) => {
      if (event.pointerType === "touch") return
      const item = event.target.closest?.("[data-nav-item]")
      if (!item || !this.el.contains(item)) return
      const list = item.closest("[data-nav-list]")
      if (!list) return
      const glide =
        !prefersReducedMotion() &&
        list === this.hoverList &&
        (this.hoverShown || performance.now() - this.hoverHiddenAt < 150)
      this.hoverList = list
      this.hoverShown = true
      this.placeFloat(list.querySelector("[data-hover]"), item, glide)
    }

    this.onPointerOut = (event) => {
      const list = event.target.closest?.("[data-nav-list]")
      if (!list || !this.el.contains(list)) return
      const next = event.relatedTarget
      if (next && list.contains(next)) return
      this.hideHover(list)
    }

    this.el.addEventListener("pointerdown", this.onPointerDown)
    this.el.addEventListener("click", this.onClick)
    this.el.addEventListener("keydown", this.onKeyDown)
    this.el.addEventListener("pointerover", this.onPointerOver)
    this.el.addEventListener("pointerout", this.onPointerOut)
    window.addEventListener("pointermove", this.onPointerMove)
    window.addEventListener("pointerup", this.onPointerUp)
    window.addEventListener("pointercancel", this.onPointerUp)

    this.observer = new ResizeObserver(([entry]) => {
      if (entry.contentRect.width >= DOCKED_WIDTH && this.drawerOpen) {
        this.closeDrawer(false)
      }
    })
    this.observer.observe(this.el)

    this.applyWidth()
    const current = this.currentId()
    const previous = readNav()
    writeNav(current)

    if (previous && previous !== current && this.hasItem(previous)) {
      this.placePills(false, previous)
      requestAnimationFrame(() => this.placePills(!prefersReducedMotion(), current))
    } else {
      this.placePills(false, current)
    }
  },

  updated() {
    this.applyWidth()
    this.applyDrawer()
    this.placePills(!prefersReducedMotion(), this.currentId())
    writeNav(this.currentId())
  },

  destroyed() {
    this.el.removeEventListener("pointerdown", this.onPointerDown)
    this.el.removeEventListener("click", this.onClick)
    this.el.removeEventListener("keydown", this.onKeyDown)
    this.el.removeEventListener("pointerover", this.onPointerOver)
    this.el.removeEventListener("pointerout", this.onPointerOut)
    window.removeEventListener("pointermove", this.onPointerMove)
    window.removeEventListener("pointerup", this.onPointerUp)
    window.removeEventListener("pointercancel", this.onPointerUp)
    this.observer?.disconnect()
    window.clearTimeout(this.closeTimer)
  },

  clamp(width) {
    return Math.round(Math.min(this.maxWidth, Math.max(this.minWidth, width)))
  },

  setWidth(width) {
    this.width = this.clamp(width)
    this.applyWidth()
  },

  applyWidth() {
    this.el.style.setProperty("--obsidian-dashboard-shell-sidebar-width", `${this.width}px`)
    const handle = this.el.querySelector("[data-resize]")
    if (handle) handle.setAttribute("aria-valuenow", String(this.width))
    if (this.dragging) this.el.setAttribute("data-resizing", "")
  },

  currentId() {
    return this.el.querySelector('[data-nav-item][data-active="true"]')?.dataset.id || ""
  },

  hasItem(id) {
    return Boolean(this.el.querySelector(`[data-nav-item][data-id="${CSS.escape(id)}"]`))
  },

  placePills(glide, id) {
    this.el.querySelectorAll("[data-nav-list]").forEach((list) => {
      const item = id ? list.querySelector(`[data-nav-item][data-id="${CSS.escape(id)}"]`) : null
      const pill = list.querySelector("[data-pill]")
      if (!pill) return
      if (!item) {
        pill.style.opacity = "0"
        return
      }
      this.placeFloat(pill, item, glide)
    })
  },

  placeFloat(element, item, glide) {
    if (!element || !item) return
    const list = item.closest("[data-nav-list]")
    const {top, left} = offsetWithin(item, list)
    element.classList.toggle("is-instant", !glide)
    element.style.transform = `translate(${left}px, ${top}px)`
    element.style.width = `${item.offsetWidth}px`
    element.style.height = `${item.offsetHeight}px`
    element.style.opacity = "1"
  },

  hideHover(list) {
    const hover = list.querySelector("[data-hover]")
    if (hover) hover.style.opacity = "0"
    this.hoverShown = false
    this.hoverHiddenAt = performance.now()
    this.hoverList = list
  },

  openDrawer() {
    window.clearTimeout(this.closeTimer)
    this.drawerOpen = true
    const root = this.el.querySelector("[data-drawer-root]")
    if (!root) return
    root.hidden = false
    root.getBoundingClientRect()
    this.applyDrawer()
    this.el.querySelector("[data-drawer-close]")?.focus()
  },

  closeDrawer(restore) {
    if (!this.drawerOpen) return
    this.drawerOpen = false
    const root = this.el.querySelector("[data-drawer-root]")
    root?.removeAttribute("data-open")
    const panel = this.el.querySelector("[data-panel]")
    const menu = this.el.querySelector("[data-menu]")
    if (menu) menu.setAttribute("aria-expanded", "false")

    const finish = () => {
      if (this.drawerOpen) return
      if (root) root.hidden = true
      panel?.removeAttribute("inert")
      if (restore) menu?.focus()
    }

    if (prefersReducedMotion()) finish()
    else this.closeTimer = window.setTimeout(finish, 280)
  },

  applyDrawer() {
    const root = this.el.querySelector("[data-drawer-root]")
    const panel = this.el.querySelector("[data-panel]")
    const menu = this.el.querySelector("[data-menu]")
    const drawer = this.el.querySelector("[data-drawer]")
    if (!root) return

    if (this.drawerOpen) {
      root.hidden = false
      root.setAttribute("data-open", "")
      panel?.setAttribute("inert", "")
      if (menu) {
        menu.setAttribute("aria-expanded", "true")
        if (drawer?.id) menu.setAttribute("aria-controls", drawer.id)
      }
    } else if (!this.closeTimer) {
      root.hidden = true
      root.removeAttribute("data-open")
      panel?.removeAttribute("inert")
      if (menu) menu.setAttribute("aria-expanded", "false")
    }
  },
}
