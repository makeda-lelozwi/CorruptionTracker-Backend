import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"
// Connects to data-controller="person-graph"
export default class extends Controller {
  static targets = ["canvas", "summary"]

  static values = {
    url: String
  }

  async connect() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          Accept: "application/json"
        }
      })

      if (!response.ok) {
        throw new Error("Graph request failed")
      }

      const data = await response.json()

      this.summaryTarget.textContent = data.narrative

      this.graph = cytoscape({
        container: this.canvasTarget,
        elements: data.elements,

        style: [
          {
            selector: "node",
            style: {
              label: "data(label)",
              "background-color": "#2563eb",
              color: "#111827",
              "text-valign": "bottom"
            }
          },
          {
            selector: "edge",
            style: {
              label: "data(label)",
              "line-color": "#94a3b8",
              "target-arrow-color": "#94a3b8",
              "target-arrow-shape": "triangle",
              "curve-style": "bezier"
            }
          }
        ],

        layout: {
          name: "cose",
          animate: false
        }
      })
    } catch (error) {
      this.canvasTarget.textContent = "Unable to load the relationship graph."
      console.error(error)
    }
  }

  disconnect() {
    this.graph?.destroy()
  }
}
