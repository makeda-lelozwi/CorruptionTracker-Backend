require "test_helper"

class PublicPersonProfileBuilderTest < ActiveSupport::TestCase
  test "summarizes a person's recorded roles and affiliations" do
    person = entity("person:alice", "Alice")
    employer = entity("org:employer", "Example Employer", label: "Organisation")
    office = entity("org:office", "Example Office", label: "Organisation")
    portfolio = entity("org:portfolio", "Example Portfolio", label: "Organisation")
    business = entity("org:business", "Alice Holdings", label: "Organisation")
    group = entity("org:group", "Example Group", label: "Organisation")
    associated_organisation = entity("org:associated", "Associated Organisation", label: "Organisation")
    associate = entity("person:bob", "Bob")
    relative = entity("person:carol", "Carol")

    insights = PublicPersonProfileBuilder.new(
      person: person,
      facts: [
        fact("RELATIVE", person, relative),
        fact("ASSOCIATE_OF", associate, person),
        fact("ASSOCIATED_WITH", person, associated_organisation),
        fact("ALLEGED_MEMBER_OF", person, group),
        fact("OWNS", person, business),
        fact("EXECUTIVE_OVERSIGHT_OF", person, portfolio),
        fact("HOLDS_POSITION", person, office, "position" => "Commissioner"),
        fact("WORKS_FOR", person, employer, "position" => "Director")
      ]
    ).call

    assert_equal [
      "Alice works for Example Employer as Director.",
      "Alice holds the position of Commissioner at Example Office.",
      "Alice has executive oversight over Example Portfolio.",
      "Alice owns Alice Holdings.",
      "Alice is allegedly a member of Example Group.",
      "Alice is associated with Bob.",
      "Alice is associated with Associated Organisation.",
      "Alice is related to Carol."
    ], insights
  end

  private
    def entity(id, name, label: "Person")
      { id: id, name: name, label: label }
    end

    def fact(relationship_type, source, target, metadata = {})
      {
        relationship_type: relationship_type,
        source: source,
        target: target,
        metadata: metadata
      }
    end
end
