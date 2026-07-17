import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"

export default class extends Controller {
  static targets = ["canvas", "data", "error"]

  connect() {
    try {
      const elements = JSON.parse(this.dataTarget.textContent)
      const rem = parseFloat(getComputedStyle(document.documentElement).fontSize)
      const isMobile = window.matchMedia(`(max-width: ${48 * rem}px)`).matches
      const graphPadding = (isMobile ? 5 : 4.3) * rem
      const nodeLabel = (node) => {
        const words = node.data("label").trim().split(/\s+/)
        return words.length > 4 ? `${words.slice(0, 4).join(" ")}…` : words.join(" ")
      }

      this.graph = cytoscape({
        container: this.canvasTarget,
        elements,
        style: [
          {
            selector: "node",
            style: {
              label: nodeLabel,
              "background-color": "#c7aff5",
              color: "#000",
              width: 6.6 * rem,
              height: 6.6 * rem,
              "font-size": 0.9 * rem,
              "text-halign": "center",
              "text-justification": "center",
              "text-max-width": 5.4 * rem,
              "text-wrap": "wrap",
              "text-valign": "center"
            }
          },
          { selector: 'node[type = "Community"]', style: { "background-color": "#e6e1ab" } },
          { selector: 'node[type = "Entity"]', style: { "background-color": "#f3c2a4" } },
          { selector: 'node[type = "Allegation"]', style: { "background-color": "#c49e63" } },
          { selector: 'node[type = "Chunk"]', style: { "background-color": "#ffb9f8" } },
          { selector: 'node[type = "Document"]', style: { "background-color": "#5cfff7" } },
          { selector: 'node[type = "Event"]', style: { "background-color": "#b5e6ff" } },
          { selector: 'node[type = "Evidence"]', style: { "background-color": "#f2a866" } },
          { selector: 'node[type = "Organisation"]', style: { "background-color": "#5dbd95" } },
          { selector: 'node[type = "Person"]', style: { "background-color": "#abaa86" } },
          { selector: 'node[type = "Testimony"]', style: { "background-color": "#98edff" } },
          {
            selector: "node[focus]",
            style: {
              width: 7.3 * rem,
              height: 7.3 * rem
            }
          },
          {
            selector: "edge",
            style: {
              label: "data(label)",
              color: "#000",
              "font-size": 0.6 * rem,
              "edge-text-rotation": "autorotate",
              "line-color": "#a3aaa6",
              "target-arrow-color": "#a3aaa6",
              "target-arrow-shape": "triangle",
              "curve-style": "bezier",
              "text-background-color": "#f1f4ef",
              "text-background-opacity": 1,
              "text-background-padding": 0.2 * rem,
              "text-background-shape": "roundrectangle",
              "text-margin-y": -0.7 * rem
            }
          }
        ],
        layout: {
          name: "cose",
          animate: false,
          componentSpacing: 7.1 * rem,
          fit: true,
          idealEdgeLength: 10 * rem,
          nodeRepulsion: 600000,
          padding: graphPadding
        }
      })

      if (isMobile) {
        requestAnimationFrame(() => {
          if (!this.graph) return

          this.graph.resize()
          this.graph.fit(this.graph.elements(), graphPadding)
          this.graph.center()
        })
      }

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
