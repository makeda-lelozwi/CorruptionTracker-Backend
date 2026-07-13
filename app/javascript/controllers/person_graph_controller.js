import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"
// Connects to data-controller="person-graph"
export default class extends Controller {
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

      const elements = await response.json()

      this.graph = cytoscape({
        container: this.element,
        elements: elements,

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
      this.element.textContent = "Unable to load the relationship graph."
      console.error(error)
    }
  }

  disconnect() {
    this.graph?.destroy()
  }
}
