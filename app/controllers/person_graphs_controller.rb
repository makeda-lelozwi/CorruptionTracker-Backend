class PersonGraphsController < ApplicationController
  EXTERNAL_ID_PATTERN = /\Aperson:[a-zA-Z0-9._-]+\z/

  PEOPLE_QUERY = <<~CYPHER.squish
    MATCH (person:Person)--()
    WHERE person.externalId STARTS WITH $prefix
    RETURN DISTINCT person.externalId AS externalId, person.name AS name
    ORDER BY toLower(coalesce(person.name, person.externalId))
  CYPHER

  QUERY = <<~CYPHER.squish
    MATCH (p:Person {externalId: $external_id})-[r]-(connectedNode)
    RETURN
      p,
      r,
      connectedNode,
      p.externalId AS personId,
      p.name AS personName,
      type(r) AS relationship,
      CASE
        WHEN startNode(r) = p THEN 'OUTGOING'
        ELSE 'INCOMING'
      END AS direction,
      labels(connectedNode)[0] AS connectedNodeType,
      connectedNode AS connectedNodeDetails
  CYPHER

  def show
  end

  def people
    rows = Neo4j::Client.new.query(
      PEOPLE_QUERY,
      parameters: { prefix: "person:" }
    )

    render json: rows.map { |row|
      {
        external_id: row.fetch("externalId"),
        name: row["name"].presence || row.fetch("externalId")
      }
    }
  rescue Neo4j::Client::Error => error
    render_neo4j_error(error)
  end

  def data
    external_id = params[:external_id].to_s

    unless EXTERNAL_ID_PATTERN.match?(external_id)
      return render json: { error: "Invalid person external ID" }, status: :unprocessable_entity
    end

    rows = Neo4j::Client.new.query(
      QUERY,
      parameters: { external_id: external_id }
    )

    render json: {
      elements: cytoscape_elements(rows),
      narrative: PersonGraphNarrative.new(rows).call
    }
  rescue Neo4j::Client::Error => error
    render_neo4j_error(error)
  end

  private

    def cytoscape_elements(rows)
      nodes = {}
      edges = {}

      rows.each do |row|
        person = row.fetch("p")
        connected_node = row.fetch("connectedNode")
        relationship = row.fetch("r")

        nodes[person.fetch("elementId")] ||= {
          data: {
            id: person.fetch("elementId"),
            label: row.fetch("personName"),
            type: "Person",
            properties: person.fetch("properties")
          }
        }

        nodes[connected_node.fetch("elementId")] ||= {
          data: {
            id: connected_node.fetch("elementId"),
            label: node_label(connected_node),
            type: row.fetch("connectedNodeType"),
            properties: connected_node.fetch("properties")
          }
        }

        edges[relationship.fetch("elementId")] ||= {
          data: {
            id: relationship.fetch("elementId"),
            source: relationship.fetch("startNodeElementId"),
            target: relationship.fetch("endNodeElementId"),
            label: row.fetch("relationship"),
            direction: row.fetch("direction"),
            properties: relationship.fetch("properties")
          }
        }
      end

      {
        nodes: nodes.values,
        edges: edges.values
      }
    end

    def node_label(node)
      properties = node.fetch("properties")

      properties["name"] ||
        properties["title"] ||
        properties["externalId"] ||
        node.fetch("labels").first
    end

    def render_neo4j_error(error)
      Rails.logger.error("Neo4j graph request failed: #{error.class}")
      render json: { error: "Unable to load graph" }, status: :bad_gateway
    end
end
