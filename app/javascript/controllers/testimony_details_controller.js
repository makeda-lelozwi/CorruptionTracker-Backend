import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const button = event.currentTarget
    const content = button.parentElement.querySelector("[data-testimony-details-content]")
    const expanded = button.ariaExpanded === "true"

    content.textContent = expanded ? content.dataset.truncated : content.dataset.full
    button.ariaExpanded = String(!expanded)
    button.textContent = expanded ? "Read more" : "Show less"
  }
}
