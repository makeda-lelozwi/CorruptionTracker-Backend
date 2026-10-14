class PublicEntityRepository
  GROUPED_QUERY = <<~CYPHER.squish
    MATCH (node)
    WHERE any(label IN labels(node) WHERE label IN $public_labels)
      AND node.externalId IS NOT NULL
      AND (
        $query = '' OR
        toLower(coalesce(node.name, '')) CONTAINS toLower($query) OR
        toLower(coalesce(node.title, '')) CONTAINS toLower($query) OR
        toLower(coalesce(node.externalId, '')) CONTAINS toLower($query)
      )
    WITH node, head([label IN $public_labels WHERE label IN labels(node)]) AS publicLabel
    ORDER BY toLower(coalesce(node.name, node.title, node.externalId))
    RETURN publicLabel, collect({
      externalId: node.externalId,
      name: coalesce(node.name, node.title, node.externalId),
      title: coalesce(node.title, node.name, node.externalId),
      date: toString(node.date),
      witness: node.witness,
      allegations: [(node)-[:DISCUSSES]->(allegation:Allegation) | {
        externalId: allegation.externalId,
        name: coalesce(allegation.title, allegation.name, allegation.externalId)
      }]
    }) AS entities
  CYPHER

  INDEX_QUERY = <<~CYPHER.squish
    MATCH (node:%<label>s)
    WHERE node.externalId IS NOT NULL
      AND (
        $query = '' OR
        toLower(coalesce(node.name, '')) CONTAINS toLower($query) OR
        toLower(coalesce(node.title, '')) CONTAINS toLower($query) OR
        toLower(coalesce(node.externalId, '')) CONTAINS toLower($query)
      )
    RETURN
      node.externalId AS externalId,
      coalesce(node.name, node.title, node.externalId) AS name,
      coalesce(node.description, node.summary) AS description
    ORDER BY toLower(coalesce(node.name, node.title, node.externalId))
  CYPHER

  SHOW_QUERY = <<~CYPHER.squish
    MATCH (subject:%<label>s {externalId: $external_id})
    OPTIONAL MATCH (subject)-[relationship]-(connected)
  WHERE connected IS NULL OR any(label IN labels(connected) WHERE label IN $public_labels)
    WITH subject, relationship, connected,
      CASE
        WHEN relationship IS NULL THEN null
        WHEN startNode(relationship) = subject THEN subject
        ELSE connected
      END AS source,
      CASE
        WHEN relationship IS NULL THEN null
        WHEN endNode(relationship) = subject THEN subject
        ELSE connected
      END AS target
    RETURN
      subject,
      relationship,
      type(relationship) AS relationshipType,
      source,
      target,
      head([label IN $public_labels WHERE label IN labels(source)]) AS sourceLabel,
      head([label IN $public_labels WHERE label IN labels(target)]) AS targetLabel
  CYPHER

  TESTIMONY_SHOW_QUERY = <<~CYPHER.squish
    MATCH (subject:Testimony {externalId: $external_id})
    OPTIONAL MATCH (subject)-[relationship:DISCUSSES]->(connected)
    WHERE connected IS NULL OR any(label IN labels(connected) WHERE label IN $public_labels)
    RETURN
      subject,
      relationship,
      type(relationship) AS relationshipType,
      subject AS source,
      connected AS target,
      'Testimony' AS sourceLabel,
      head([label IN $public_labels WHERE label IN labels(connected)]) AS targetLabel
  CYPHER

  EVENT_TRAIL_QUERY = <<~CYPHER.squish
    MATCH (focus:Event {externalId: $external_id})
    OPTIONAL MATCH backward = (ancestor:Event)-[:LED_TO*1..10]->(focus)
    WITH focus, backward
    ORDER BY length(backward) DESC
    WITH focus, head(collect(backward)) AS backward
    WITH focus,
      CASE WHEN backward IS NULL THEN [focus] ELSE nodes(backward) END AS history
    OPTIONAL MATCH forward = (focus)-[:LED_TO*1..2]->(later:Event)
    WITH focus, history, later, forward
    ORDER BY length(forward), toLower(coalesce(later.title, later.name, later.externalId))
    RETURN
      [node IN history | {
        externalId: node.externalId,
        name: coalesce(node.title, node.name, node.externalId)
      }] AS history,
      collect(DISTINCT CASE WHEN later IS NULL THEN null ELSE {
        externalId: later.externalId,
        name: coalesce(later.title, later.name, later.externalId),
        depth: length(forward)
      } END) AS future
  CYPHER

  def initialize(client: Neo4j::Client.new)
    @client = client
  end

  def grouped(query: "")
    client.query(
      GROUPED_QUERY,
      parameters: { public_labels: PublicEntityCatalog::LABELS, query: query.to_s.strip }
    )
  end

  def all(label:, query: "")
    entry = PublicEntityCatalog.fetch(label)
    client.query(
      format(INDEX_QUERY, label: entry.label),
      parameters: { query: query.to_s.strip }
    )
  end

  def find(label:, external_id:)
    entry = PublicEntityCatalog.fetch(label)
    client.query(
      entry.label == "Testimony" ? TESTIMONY_SHOW_QUERY : format(SHOW_QUERY, label: entry.label),
      parameters: {
        external_id: external_id,
        public_labels: PublicEntityCatalog::LABELS
      }
    )
  end

  def event_trail(external_id:)
    client.query(
      EVENT_TRAIL_QUERY,
      parameters: { external_id: external_id }
    )
  end

  private
    attr_reader :client
end
