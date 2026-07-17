require "test_helper"

class PublicEntitiesControllerTest < ActionDispatch::IntegrationTest
  test "lists one public entity type" do
    client = fake_client([ {
      "externalId" => "person:alice",
      "name" => "Alice",
      "description" => "A public description"
    } ])

    with_neo4j_client(client) { get people_url }

    assert_response :success
    assert_select "h1", "People"
    assert_select "a[href='/people/person:alice']", "Alice"
  end

  test "paginates entity indexes in groups of five" do
    rows = 6.times.map do |index|
      {
        "externalId" => "person:person-#{index + 1}",
        "name" => "Person #{index + 1}"
      }
    end
    client = fake_client(rows)

    with_neo4j_client(client) { get people_url }

    assert_response :success
    assert_select ".entity-list--index li", count: 5
    assert_select ".pagination a", text: "2" do |links|
      assert_equal "/people?page=2", links.first["href"]
    end
    assert_select "a[href='/people/person:person-6']", count: 0

    with_neo4j_client(client) { get people_url(page: 2) }

    assert_response :success
    assert_select ".entity-list--index li", count: 1
    assert_select "a[href='/people/person:person-6']", "Person 6"
  end

  test "renders connected public entities" do
    client = fake_client(show_rows(quote: "<script>alert('x')</script>"))

    with_neo4j_client(client) do
      get person_url(external_id: "person:alice")
    end

    assert_response :success
    assert_select "h2", "Related to"
    assert_select ".connected-records--primary a[href='/organisations/org:example']", "Example Organisation"
    assert_select ".connected-records__relationship", text: "Alice is recorded as working for Example Organisation. Their work overlapped during the inquiry."
    assert_select ".person-profile li", text: "Alice works for Example Organisation as Director."
    assert_not_includes response.body, "<script>alert('x')</script>"
    assert_select "[data-controller='public-graph']"
  end

  test "does not query Neo4j for an invalid external ID" do
    client = Object.new
    client.define_singleton_method(:query) { |_statement, parameters:| flunk "Neo4j should not be queried" }

    with_neo4j_client(client) do
      get person_url(external_id: "invalid")
    end

    assert_response :not_found
  end

  test "returns not found when a public entity does not exist" do
    with_neo4j_client(fake_client([])) do
      get event_url(external_id: "event:missing")
    end

    assert_response :not_found
  end

  test "accepts testimony IDs containing more than one colon" do
    testimony = neo4j_node(
      "Testimony",
      "testimony:madlanga:2025-09-19",
      "Day 3 Testimony",
      "testimony-node"
    )
    client = fake_client([ {
      "subject" => testimony,
      "relationship" => nil,
      "relationshipType" => nil,
      "source" => nil,
      "target" => nil,
      "sourceLabel" => nil,
      "targetLabel" => nil
    } ])

    with_neo4j_client(client) do
      get testimony_url(external_id: "testimony:madlanga:2025-09-19")
    end

    assert_response :success
    assert_select "h1", "Day 3 Testimony"
    assert_select "h2", "Discussed in this testimony"
  end

  test "returns a safe error page for a Neo4j failure" do
    client = Object.new
    client.define_singleton_method(:query) { |_statement, parameters:| raise Neo4j::Client::RequestError, "private detail" }

    with_neo4j_client(client) do
      get people_url
    end

    assert_response :bad_gateway
    assert_select "h1", "The evidence web is temporarily unavailable"
    assert_no_match(/private detail/, response.body)
  end

  private
    def fake_client(rows)
      Object.new.tap do |client|
        client.define_singleton_method(:query) { |_statement, parameters:| rows }
      end
    end

    def show_rows(quote:)
      person = neo4j_node("Person", "person:alice", "Alice", "person-node")
      organisation = neo4j_node("Organisation", "org:example", "Example Organisation", "organisation-node")

      [ {
        "subject" => person,
        "relationship" => {
          "elementId" => "relationship:1",
          "properties" => {
            "quote" => quote,
            "page" => 7,
            "position" => "Director",
            "description" => "their work overlapped during the inquiry"
          }
        },
        "relationshipType" => "WORKS_FOR",
        "source" => person,
        "target" => organisation,
        "sourceLabel" => "Person",
        "targetLabel" => "Organisation"
      } ]
    end

    def neo4j_node(label, external_id, name, element_id)
      {
        "elementId" => element_id,
        "labels" => [ label ],
        "properties" => {
          "externalId" => external_id,
          "name" => name
        }
      }
    end
end
