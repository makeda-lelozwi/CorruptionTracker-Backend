require "test_helper"

class PublicGraphFactBuilderTest < ActiveSupport::TestCase
  test "uses the complete pattern when two relationships have the same type" do
    allegation = build_result(
      source_label: "Event",
      relationship_type: "LED_TO",
      target_label: "Allegation",
      source_name: "A briefing",
      target_name: "An allegation"
    ).facts.first
    event = build_result(
      source_label: "Event",
      relationship_type: "LED_TO",
      target_label: "Event",
      source_name: "A briefing",
      target_name: "An investigation"
    ).facts.first

    assert_equal "The dataset records A briefing as leading to the allegation “An allegation”.", allegation[:sentence]
    assert_equal "The dataset records A briefing as leading to An investigation.", event[:sentence]
  end

  test "reverses a pattern for natural public wording" do
    fact = build_result(
      source_label: "Event",
      relationship_type: "VICTIM",
      target_label: "Person",
      source_name: "Murder of Armand Swart",
      target_name: "Armand Swart"
    ).facts.first

    assert_equal "Armand Swart was the victim in Murder of Armand Swart.", fact[:sentence]
    assert_equal :reverse, fact[:direction]
  end

  test "uses a cautious fallback for an unknown exact pattern" do
    fact = build_result(
      source_label: "Person",
      relationship_type: "UNMAPPED_LINK",
      target_label: "Event",
      source_name: "A person",
      target_name: "An event"
    ).facts.first

    assert_equal "A person is connected to An event through UNMAPPED_LINK.", fact[:sentence]
    assert_equal "Other connections", fact[:lane]
  end

  test "keeps only approved relationship metadata and nearby citation fields" do
    fact = build_result(
      source_label: "Person",
      relationship_type: "SUBJECT_OF",
      target_label: "Allegation",
      properties: {
        "quote" => "Source quotation",
        "page" => 147,
        "role" => "subject",
        "reason" => "Recorded reason",
        "privateField" => "must not be public"
      }
    ).facts.first

    assert_equal "Source quotation", fact[:quote]
    assert_equal 147, fact[:page]
    assert_equal({ "role" => "subject", "reason" => "Recorded reason" }, fact[:metadata])
    refute_includes fact[:metadata].keys, "privateField"
    assert_equal "Allegations and complaints", fact[:lane]
  end

  test "limits the supporting graph to 25 public nodes" do
    entity = graph_entity("person:focus", "Focus")
    facts = 30.times.map do |index|
      related = graph_entity("person:#{index}", "Person #{index}")
      {
        id: "relationship:#{index}",
        source: entity,
        target: related,
        relationship_type: "ASSOCIATE_OF"
      }
    end

    graph = PublicEntityGraph.new(entity: entity, facts: facts).call

    assert_equal 25, graph[:elements][:nodes].length
    assert_equal 24, graph[:elements][:edges].length
    assert_equal 6, graph[:omitted_node_count]
  end

  private
    def build_result(
      source_label:,
      relationship_type:,
      target_label:,
      source_name: "Source",
      target_name: "Target",
      properties: {}
    )
      source = neo4j_node(source_label, "#{source_label.downcase}:source", source_name, "source")
      target = neo4j_node(target_label, "#{target_label.downcase}:target", target_name, "target")

      PublicGraphFactBuilder.new([ {
        "subject" => source,
        "source" => source,
        "target" => target,
        "sourceLabel" => source_label,
        "targetLabel" => target_label,
        "relationshipType" => relationship_type,
        "relationship" => {
          "elementId" => "relationship:1",
          "properties" => properties
        }
      } ]).call
    end

    def neo4j_node(label, external_id, name, element_id)
      property_name = %w[Person Organisation].include?(label) ? "name" : "title"
      {
        "elementId" => element_id,
        "labels" => [ label ],
        "properties" => {
          "externalId" => external_id,
          property_name => name
        }
      }
    end

    def graph_entity(external_id, name)
      {
        id: external_id,
        label: "Person",
        external_id: external_id,
        name: name,
        path: "/people/#{external_id}"
      }
    end
end
