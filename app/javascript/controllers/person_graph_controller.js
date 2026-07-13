import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"
// Connects to data-controller="person-graph"
export default class extends Controller {
  static targets = ["canvas", "summary", "personSelect"]

  static values = {
    url: String,
    peopleUrl: String
  }

  async connect() {
    try {
      const people = await this.fetchJson(this.peopleUrlValue)

      if (people.length === 0) {
        this.canvasTarget.textContent = "No connected people were found."
        return
      }

      this.personSelectTarget.replaceChildren(
        ...people.map((person) => {
          const option = document.createElement("option")
          option.value = person.external_id
          option.textContent = person.name
          return option
        })
      )

      await this.loadGraph(people[0].external_id)
    } catch (error) {
      this.showError(error)
    }
  }

  async changePerson(event) {
    try {
      await this.loadGraph(event.currentTarget.value)
    } catch (error) {
      this.showError(error)
    }
  }

  async loadGraph(externalId) {
    const query = new URLSearchParams({ external_id: externalId })
    const data = await this.fetchJson(`${this.urlValue}?${query}`)

    this.summaryTarget.textContent = data.narrative
    this.graph?.destroy()
    this.canvasTarget.textContent = ""

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
  }

  async fetchJson(url) {
    const response = await fetch(url, {
      headers: {
        Accept: "application/json"
      }
    })

    if (!response.ok) {
      throw new Error("Graph request failed")
    }

    return response.json()
  }

  showError(error) {
    this.canvasTarget.textContent = "Unable to load the relationship graph."
    this.summaryTarget.textContent = ""
    console.error(error)
  }

  disconnect() {
    this.graph?.destroy()
  }
}
