import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "input"]

  open(event) {
    event.preventDefault()
    this.dialogTarget.classList.add("is-open")
    requestAnimationFrame(() => this.inputTarget.focus())
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.classList.remove("is-open")

    if (window.location.hash === "#spotlight-search-modal") {
      history.replaceState(null, "", `${window.location.pathname}${window.location.search}`)
    }
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close(event)
  }

  disconnect() {
    this.dialogTarget.classList.remove("is-open")
  }
}
