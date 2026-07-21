require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows grouped public entity previews from the root route" do
    client = fake_client([
      {
        "publicLabel" => "Person",
        "entities" => [
          { "externalId" => "person:alice", "name" => "Alice" }
        ]
      },
      {
        "publicLabel" => "Testimony",
        "entities" => [ {
          "externalId" => "testimony:madlanga:2025-09-18",
          "name" => "Day 2 - Alice Testimony",
          "title" => "Day 2 - Alice Testimony",
          "date" => "2025-09-18",
          "witness" => "Alice",
          "allegations" => []
        } ]
      }
    ])

    with_neo4j_client(client) do
      get root_url
    end

    assert_response :success
    assert_select ".latest-testimony .home-eyebrow", "Latest testimony hearing"
    assert_select "h1", "18 September 2025, Day 2"
    assert_select ".latest-testimony__witness", /Witness\s*Alice/
    assert_select "a[href='/testimonies/testimony:madlanga:2025-09-18']", "read more >"
    assert_select ".testimony-timeline a[href='/testimonies/testimony:madlanga:2025-09-18']", /Day 2/
    assert_select "a[href='/people/person:alice']", "Alice"
    assert_select ".home-index__section", count: 4

    with_neo4j_client(client) do
      get root_url(q: "day 2")
    end

    assert_select ".dashboard-stat", "1"
    assert_select ".home-overview .dashboard-links a[href='/people']", /People\s*1/
  end

  test "shows a safe error when Neo4j is unavailable" do
    client = Object.new
    client.define_singleton_method(:query) { |_statement, parameters:| raise Neo4j::Client::RequestError, "private detail" }

    with_neo4j_client(client) do
      get root_url
    end

    assert_response :bad_gateway
    assert_select ".notice--error", /temporarily unavailable/
    assert_no_match(/private detail/, response.body)
  end

  private
    def fake_client(rows)
      Object.new.tap do |client|
        client.define_singleton_method(:query) { |_statement, parameters:| rows }
      end
    end
end
