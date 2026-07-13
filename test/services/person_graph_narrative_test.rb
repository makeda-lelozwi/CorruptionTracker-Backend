require "test_helper"

class PersonGraphNarrativeTest < ActiveSupport::TestCase
  test "groups graph relationships into a cautious narrative" do
    narrative = PersonGraphNarrative.new(rows).call

    assert_equal(
        "According to the source material represented in the current dataset, " \
        "Shadrack Sibiya is identified as Deputy National Commissioner for Crime Detection " \
        "within the South African Police Service. " \
        "Shadrack Sibiya is the subject of allegations concerning R580 million irregular expenditure and " \
        "R3.5 million unlawful benefit and Association with criminal syndicates. " \
        "Shadrack Sibiya is also alleged in the source material to be a member of The Big Five cartel and " \
        "recorded as associated with Vusimuzi “Cat” Matlala. " \
        "The dataset further connects Shadrack Sibiya to the event “Instruction to Disband PKTT”.",
      narrative
    )
  end

  test "returns an empty narrative when the query has no results" do
    assert_equal "", PersonGraphNarrative.new([]).call
  end

  private
    def rows
      [
        row("WORKS_FOR", "Organisation", "South African Police Service",
          relationship_properties: { "position" => "Deputy National Commissioner for Crime Detection" }),
        row("SUBJECT_OF", "Allegation", "R580 million irregular expenditure and R3.5 million unlawful benefit"),
        row("SUBJECT_OF", "Allegation", "Association with criminal syndicates"),
        row("ALLEGED_MEMBER_OF", "Organisation", "The Big Five cartel"),
        row("ASSOCIATE_OF", "Person", "Vusimuzi “Cat” Matlala"),
        row("INVOLVES", "Event", "Instruction to Disband PKTT")
      ]
    end

    def row(relationship, connected_node_type, connected_name, relationship_properties: {})
      {
        "personName" => "Shadrack Sibiya",
        "relationship" => relationship,
        "connectedNodeType" => connected_node_type,
        "p" => {
          "properties" => { "title" => "Deputy National Commissioner" }
        },
        "r" => {
          "properties" => relationship_properties
        },
        "connectedNode" => {
          "properties" => { "name" => connected_name }
        }
      }
    end
end
