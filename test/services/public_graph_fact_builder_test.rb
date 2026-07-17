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
    assert_equal "A briefing led to An investigation.", event[:sentence]
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

  test "uses the relationship type as the fallback verb phrase" do
    fact = build_result(
      source_label: "Person",
      relationship_type: "CONTACTED",
      target_label: "Person",
      source_name: "A person",
      target_name: "Another person"
    ).facts.first

    assert_equal "A person contacted Another person.", fact[:sentence]
    assert_equal "Other connections", fact[:lane]
  end

  test "writes a raised event relationship as a natural sentence" do
    fact = build_result(
      source_label: "Person",
      relationship_type: "RAISED",
      target_label: "Event",
      source_name: "Fannie Masemola",
      target_name: "University of Fort Hare murders investigation"
    ).facts.first

    assert_equal "Fannie Masemola raised the University of Fort Hare murders investigation.", fact[:sentence]
    assert_equal "Events and causality", fact[:lane]
  end

  test "writes an event received by a person as a natural sentence" do
    fact = build_result(
      source_label: "Event",
      relationship_type: "RECEIVED_COMPLAINT",
      target_label: "Person",
      source_name: "City of Johannesburg urgent request to Minister of Police",
      target_name: "Senzo Mchunu"
    ).facts.first

    assert_equal "City of Johannesburg urgent request to Minister of Police received by Senzo Mchunu.", fact[:sentence]
    assert_equal "Allegations and complaints", fact[:lane]
  end

  test "does not repeat the recipient for a presentation event" do
    fact = build_result(
      source_label: "Event",
      relationship_type: "PRESENTED_TO",
      target_label: "Person",
      source_name: "Khumalo presented PKTT successes and operational workload to Minister Mchunu",
      target_name: "Senzo Mchunu"
    ).facts.first

    assert_equal "Khumalo presented PKTT successes and operational workload to Senzo Mchunu.", fact[:sentence]
    assert_equal "Communication", fact[:lane]
  end

  test "uses a complete briefing event title without repeating informed" do
    fact = build_result(
      source_label: "Event",
      relationship_type: "INFORMED",
      target_label: "Person",
      source_name: "Masemola and Khumalo briefed Minister Mchunu on the Big Five syndicate",
      target_name: "Senzo Mchunu"
    ).facts.first

    assert_equal "Masemola and Khumalo briefed Minister Mchunu on the Big Five syndicate.", fact[:sentence]
    assert_equal "Communication", fact[:lane]
  end

  test "describes a reported associate naturally" do
    fact = build_result(
      source_label: "Person",
      relationship_type: "ASSOCIATE_OF",
      target_label: "Person",
      source_name: "Brown Mogotsi",
      target_name: "Senzo Mchunu"
    ).facts.first

    assert_equal "Brown Mogotsi is reported to be an associate of Senzo Mchunu.", fact[:sentence]
    assert_equal "Roles and affiliations", fact[:lane]
  end

  test "does not repeat instruction in an issued instruction relationship" do
    fact = build_result(
      source_label: "Person",
      relationship_type: "ISSUED_INSTRUCTION",
      target_label: "Event",
      source_name: "Senzo Mchunu",
      target_name: "Instruction to Disband PKTT"
    ).facts.first

    assert_equal "Senzo Mchunu issued Instruction to Disband PKTT.", fact[:sentence]
    assert_equal "Communication", fact[:lane]
  end

  test "describes the subject of an allegation without quotation marks" do
    fact = build_result(
      source_label: "Person",
      relationship_type: "SUBJECT_OF",
      target_label: "Allegation",
      source_name: "Julius Mkhwanazi",
      target_name: "Alleged abuse of EMPD for the benefit of Vusimuzi Matlala"
    ).facts.first

    assert_equal "Julius Mkhwanazi is the subject of the allegation of alleged abuse of EMPD for the benefit of Vusimuzi Matlala.", fact[:sentence]
    assert_equal "Allegations and complaints", fact[:lane]
  end

  test "turns an establishment event title into a natural object" do
    fact = build_result(
      source_label: "Person",
      relationship_type: "ESTABLISHED",
      target_label: "Event",
      source_name: "Cyril Ramaphosa",
      target_name: "Establishment of the Madlanga Commission of Inquiry"
    ).facts.first

    assert_equal "Cyril Ramaphosa established the Madlanga Commission of Inquiry.", fact[:sentence]
    assert_equal "Events and causality", fact[:lane]
  end

  test "turns an appointed event title into an appointment object" do
    fact = build_result(
      source_label: "Person",
      relationship_type: "ORDERED",
      target_label: "Event",
      source_name: "Fannie Masemola",
      target_name: "Lt Gen Patekile appointed to investigate misconduct allegations against Lt Gen Sibiya"
    ).facts.first

    assert_equal "Fannie Masemola ordered appointment of Lt Gen Patekile to investigate misconduct allegations against Lt Gen Sibiya.", fact[:sentence]
    assert_equal "Events and causality", fact[:lane]
  end

  test "identifies an allegation target in fallback wording" do
    fact = build_result(
      source_label: "Event",
      relationship_type: "CONTRADICTS",
      target_label: "Allegation",
      source_name: "University of Fort Hare murders investigation",
      target_name: "PKTT no longer required or adding value."
    ).facts.first

    assert_equal "University of Fort Hare murders investigation contradicts the allegation of PKTT no longer required or adding value.", fact[:sentence]
    assert_equal "Evidence", fact[:lane]
  end

  test "does not inject the word event into testimony wording" do
    fact = build_result(
      source_label: "Testimony",
      relationship_type: "DISCUSSES",
      target_label: "Event",
      source_name: "Day 9 - Continued testimony of Lt Gen Dumisani Khumalo",
      target_name: "SAPS terminated the Medicare24 health-risk services contract"
    ).facts.first

    assert_equal "Day 9 - Continued testimony of Lt Gen Dumisani Khumalo discusses “SAPS terminated the Medicare24 health-risk services contract”.", fact[:sentence]
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

  test "humanizes a relationship description" do
    fact = build_result(
      source_label: "Event",
      relationship_type: "LED_TO",
      target_label: "Event",
      properties: { "description" => "  complaint prompted the investigation  " }
    ).facts.first

    assert_equal "Complaint prompted the investigation.", fact[:description]
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
