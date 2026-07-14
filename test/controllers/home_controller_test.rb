require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows grouped public entity previews from the root route" do
    client = fake_client([ {
      "publicLabel" => "Person",
      "entities" => [
        { "externalId" => "person:alice", "name" => "Alice" }
      ]
    } ])

    with_neo4j_client(client) do
      get root_url
    end

    assert_response :success
    assert_select "h1", "Explore people, events and evidence"
    assert_select "a[href='/people/person:alice']", "Alice"
    assert_select ".entity-section", count: 6
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
