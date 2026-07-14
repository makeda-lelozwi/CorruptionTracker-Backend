import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"

export default class extends Controller {
  static targets = ["canvas", "data", "error"]

  connect() {
    try {
      const elements = JSON.parse(this.dataTarget.textContent)
      const rem = parseFloat(getComputedStyle(document.documentElement).fontSize)

      this.graph = cytoscape({
        container: this.canvasTarget,
        elements,
        style: [
          {
            selector: "node",
            style: {
              label: "data(label)",
              "background-color": "#315c4b",
              color: "#17201c",
              "font-size": 0.9 * rem,
              "text-max-width": 9.3 * rem,
              "text-wrap": "wrap",
              "text-valign": "bottom"
            }
          },
          {
            selector: "node[focus]",
            style: {
              "background-color": "#b45309",
              width: 3 * rem,
              height: 3 * rem
            }
          },
          {
            selector: "edge",
            style: {
              label: "data(label)",
              "font-size": 0.6 * rem,
              "line-color": "#a3aaa6",
              "target-arrow-color": "#a3aaa6",
              "target-arrow-shape": "triangle",
              "curve-style": "bezier"
            }
          }
        ],
        layout: { name: "cose", animate: false }
      })

      this.graph.on("tap", "node", (event) => {
        const path = event.target.data("path")
        if (path) window.location.assign(path)
      })
    } catch (error) {
      this.canvasTarget.hidden = true
      this.errorTarget.hidden = false
      this.errorTarget.textContent = "The relationship map could not be displayed. All written relationships remain available above."
      console.error(error)
    }
  }

  disconnect() {
    this.graph?.destroy()
  }
}
