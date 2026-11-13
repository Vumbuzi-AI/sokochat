// A single-choice listbox that keeps the LiveView form's hidden field in sync.
export const SelectMenu = {
  mounted() {
    this.onClick = event => {
      const option = event.target.closest('[data-option]')
      if (option && this.el.contains(option)) {
        const input = this.el.querySelector('input')
        input.value = option.dataset.value
        this.el.querySelector('[data-label]').textContent = option.textContent.trim()
        this.close(true)
        input.dispatchEvent(new Event('input', {bubbles: true}))
      } else if (event.target.closest('[data-trigger]')) {
        this.isOpen() ? this.close() : this.open()
      }
    }
    this.onOutside = event => { if (!this.el.contains(event.target)) this.close() }
    this.onFocusOut = event => { if (!this.el.contains(event.relatedTarget)) this.close() }
    this.onKey = event => {
      const options = [...this.el.querySelectorAll('[data-option]')]
      const index = options.indexOf(document.activeElement)
      if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
        event.preventDefault()
        if (!this.isOpen()) return this.open(event.key === 'ArrowUp' || event.key === 'End')
        const next = event.key === 'Home' ? 0 : event.key === 'End' ? options.length - 1 :
          (index + (event.key === 'ArrowDown' ? 1 : -1) + options.length) % options.length
        options[next]?.focus()
      } else if (event.key === 'Escape' && this.isOpen()) {
        event.preventDefault()
        event.stopPropagation()
        this.close(true)
      } else if (event.key.length === 1 && /\S/.test(event.key)) {
        this.query = (this.query || '') + event.key.toLowerCase()
        clearTimeout(this.queryTimer)
        this.queryTimer = setTimeout(() => { this.query = '' }, 700)
        if (!this.isOpen()) this.open()
        options.find(option => option.textContent.trim().toLowerCase().startsWith(this.query))?.focus()
        event.preventDefault()
      }
    }
    this.el.addEventListener('click', this.onClick)
    this.el.addEventListener('keydown', this.onKey)
    this.el.addEventListener('focusout', this.onFocusOut)
    document.addEventListener('pointerdown', this.onOutside)
  },
  isOpen() { return this.el.querySelector('[data-trigger]').getAttribute('aria-expanded') === 'true' },
  open(last = false) {
    this.el.querySelector('[data-trigger]').setAttribute('aria-expanded', 'true')
    this.el.querySelector('[role="listbox"]').hidden = false
    const options = [...this.el.querySelectorAll('[data-option]')]
    const selected = options.find(option => option.getAttribute('aria-selected') === 'true')
    ;(selected || options[last ? options.length - 1 : 0])?.focus()
  },
  close(focus = false) {
    this.el.querySelector('[data-trigger]').setAttribute('aria-expanded', 'false')
    this.el.querySelector('[role="listbox"]').hidden = true
    if (focus) this.el.querySelector('[data-trigger]').focus()
  },
  updated() { this.close() },
  destroyed() {
    clearTimeout(this.queryTimer)
    this.el.removeEventListener('click', this.onClick)
    this.el.removeEventListener('keydown', this.onKey)
    this.el.removeEventListener('focusout', this.onFocusOut)
    document.removeEventListener('pointerdown', this.onOutside)
  }
}
