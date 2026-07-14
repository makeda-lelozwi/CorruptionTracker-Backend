ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def with_neo4j_client(client)
      original_new = Neo4j::Client.method(:new)
      Neo4j::Client.singleton_class.define_method(:new) { |*| client }
      yield
    ensure
      Neo4j::Client.singleton_class.define_method(:new, original_new)
    end
  end
end
