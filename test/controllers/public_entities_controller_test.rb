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

  test "renders a fact with escaped citation and metadata" do
    client = fake_client(show_rows(quote: "<script>alert('x')</script>"))

    with_neo4j_client(client) do
      get person_url(external_id: "person:alice")
    end

    assert_response :success
    assert_select ".fact-card__sentence", /Alice is recorded as working for Example Organisation/
    assert_select ".citation", text: /<script>alert\('x'\)<\/script>/
    assert_not_includes response.body, "<script>alert('x')</script>"
    assert_select ".fact-metadata dt", "Position"
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
            "position" => "Director"
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
