import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"
// Connects to data-controller="person-graph"
export default class extends Controller {
  connect() {
    this.graph = cytoscape({
      container: this.element,

      elements: [
        {
          data: {
            id: "shadrack",
            label: "Shadrack Sibiya"
          }
        },
        {
          data: {
            id: "saps",
            label: "South African Police Service"
          }
        },
        {
          data: {
            id: "works-for",
            source: "shadrack",
            target: "saps",
            label: "WORKS_FOR"
          }
        }
      ],

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
            "target-arrow-shape": "triangle",
            "curve-style": "bezier"
          }
        }
      ],

      layout: {
        name: "grid"
      }
    })
  }
  
  disconnect() {
    this.graph.destroy()
  }
}
