class PersonGraphsController < ApplicationController
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
  
  def data
    rows = Neo4j::Client.new.query(
      QUERY,
      parameters: {
        external_id: "person:lt-general-shadrack-sibiya"
      }
    )

    render json: cytoscape_elements(rows)
  rescue Neo4j::Client::Error => error
    Rails.logger.error("Neo4j graph request failed: #{error.class}")

    render json: {
      error: "Unable to load graph"
    }, status: :bad_gateway
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
end
