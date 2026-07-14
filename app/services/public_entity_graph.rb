class PublicEntityGraph
  MAX_NODES = 25

  def initialize(entity:, facts:)
    @entity = entity
    @facts = facts
  end

  def call
    nodes = { entity.fetch(:id) => node_element(entity, focus: true) }
    edges = {}

    facts.each do |fact|
      related = related_entity(fact)
      next if !nodes.key?(related.fetch(:id)) && nodes.length >= MAX_NODES

      nodes[related.fetch(:id)] ||= node_element(related)
      next unless nodes.key?(fact[:source][:id]) && nodes.key?(fact[:target][:id])

      edges[fact.fetch(:id)] ||= {
        data: {
          id: fact.fetch(:id),
          source: fact[:source][:id],
          target: fact[:target][:id],
          label: fact.fetch(:relationship_type)
        }
      }
    end

    {
      elements: { nodes: nodes.values, edges: edges.values },
      omitted_node_count: [ unique_related_count - (nodes.length - 1), 0 ].max
    }
  end

  private
    attr_reader :entity, :facts

    def related_entity(fact)
      fact[:source][:id] == entity[:id] ? fact[:target] : fact[:source]
    end

    def unique_related_count
      facts.map { |fact| related_entity(fact)[:id] }.uniq.length
    end

    def node_element(item, focus: false)
      data = {
        id: item.fetch(:id),
        label: item.fetch(:name),
        type: item.fetch(:label),
        path: item.fetch(:path)
      }
      data[:focus] = true if focus
      { data: data }
    end
end
