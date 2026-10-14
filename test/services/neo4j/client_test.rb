require "test_helper"

class Neo4j::ClientTest < ActiveSupport::TestCase
  test "maps fields and values into row hashes" do
    response = response_with(
      code: "202",
      body: {
        data: {
          fields: [ "name", "count" ],
          values: [ [ "Alice", 2 ], [ "Bob", 1 ] ]
        }
      }.to_json
    )
    client = stubbed_client(response)

    rows = client.query("MATCH (person:Person) RETURN person.name AS name, 1 AS count")

    assert_equal [ { "name" => "Alice", "count" => 2 }, { "name" => "Bob", "count" => 1 } ], rows
  end

  test "requires all connection credentials" do
    error = assert_raises(Neo4j::Client::ConfigurationError) do
      build_client(username: nil)
    end

    assert_equal(
      "Missing Neo4j username; set NEO4J_USERNAME or add neo4j.username to Rails credentials",
      error.message
    )
  end

  test "uses environment variables for connection settings" do
    with_environment(
      "NEO4J_URI" => "neo4j+s://environment.databases.neo4j.io",
      "NEO4J_USERNAME" => "environment-user",
      "NEO4J_PASSWORD" => "environment-password",
      "NEO4J_DATABASE" => "corruption"
    ) do
      response = response_with(code: "202", body: { data: { fields: [ "value" ], values: [ [ 1 ] ] } }.to_json)
      client = stubbed_client(response, client: Neo4j::Client.new)

      client.query("RETURN 1 AS value")

      assert_equal "environment.databases.neo4j.io", client.sent_request.uri.host
      assert_equal "/db/corruption/query/v2", client.sent_request.uri.path
      assert_equal(
        "Basic #{Base64.strict_encode64("environment-user:environment-password")}",
        client.sent_request["Authorization"]
      )
    end
  end

  test "rejects malformed connection URIs" do
    error = assert_raises(Neo4j::Client::ConfigurationError) do
      build_client(connection_uri: "bolt://example.com")
    end

    assert_match(/must use neo4j\+s:\/\/ or https:\/\//, error.message)
  end

  test "raises a sanitized authentication error" do
    client = stubbed_client(response_with(code: "401", body: {
      errors: [ { code: "Neo.ClientError.Security.Unauthorized", message: "secret details" } ]
    }.to_json))

    error = assert_raises(Neo4j::Client::AuthenticationError) { client.query("RETURN 1") }

    assert_equal "Neo4j Aura authentication failed", error.message
    refute_includes error.message, "secret details"
  end

  test "raises a sanitized Cypher error from a successful HTTP response" do
    client = stubbed_client(response_with(code: "202", body: {
      errors: [ { code: "Neo.ClientError.Statement.SyntaxError", message: "query details" } ]
    }.to_json))

    error = assert_raises(Neo4j::Client::QueryError) { client.query("invalid query") }

    assert_equal "Neo4j query failed (Neo.ClientError.Statement.SyntaxError)", error.message
    refute_includes error.message, "query details"
  end

  test "sends parameters in the JSON request body" do
    response = response_with(code: "202", body: { data: { fields: [ "value" ], values: [ [ 7 ] ] } }.to_json)
    client = stubbed_client(response)

    client.query("RETURN $number AS value", parameters: { number: 7 })

    assert_equal(
      { "statement" => "RETURN $number AS value", "parameters" => { "number" => 7 } },
      JSON.parse(client.sent_request.body)
    )
    assert_equal "/db/neo4j/query/v2", client.sent_request.uri.path
    assert_equal "Basic #{Base64.strict_encode64("neo4j:password")}", client.sent_request["Authorization"]
  end

  private
    def build_client(**overrides)
      Neo4j::Client.new(**{
        connection_uri: "neo4j+s://example.databases.neo4j.io",
        username: "neo4j",
        password: "password"
      }.merge(overrides))
    end

    def stubbed_client(response, client: build_client)
      client.define_singleton_method(:perform_request) do |request|
        @sent_request = request
        response
      end
      client.define_singleton_method(:sent_request) { @sent_request }
      client
    end

    def response_with(code:, body:)
      response_class = code.to_i.between?(200, 299) ? Net::HTTPAccepted : Net::HTTPUnauthorized
      response = response_class.new("1.1", code, "Response")
      response.instance_variable_set(:@read, true)
      response.body = body
      response
    end

    def with_environment(values)
      original_values = values.to_h { |key, _value| [ key, ENV[key] ] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      original_values.each { |key, value| ENV[key] = value }
    end
end
