require "json"
require "net/http"
require "uri"

module Neo4j
  class Client
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class AuthenticationError < Error; end
    class RequestError < Error; end
    class QueryError < Error; end
    class ResponseError < Error; end

    DEFAULT_DATABASE = "neo4j"
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_READ_TIMEOUT = 30
    DATABASE_NAME_PATTERN = /\A[a-zA-Z0-9._-]+\z/
    ENVIRONMENT_VARIABLES = {
      connection_uri: "NEO4J_URI",
      username: "NEO4J_USERNAME",
      password: "NEO4J_PASSWORD",
      database: "NEO4J_DATABASE"
    }.freeze

    def initialize(
      connection_uri: setting(:connection_uri),
      username: setting(:username),
      password: setting(:password),
      database: setting(:database) || DEFAULT_DATABASE,
      open_timeout: DEFAULT_OPEN_TIMEOUT,
      read_timeout: DEFAULT_READ_TIMEOUT
    )
      @base_uri = normalize_uri(connection_uri)
      @username = require_setting(username, "username")
      @password = require_setting(password, "password")
      @database = validate_database(database)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def query(statement, parameters: {})
      raise ArgumentError, "statement must be present" if statement.to_s.strip.empty?
      raise ArgumentError, "parameters must be a Hash" unless parameters.is_a?(Hash)

      response = perform_request(build_request(statement, parameters))
      payload = parse_response(response)
      raise_response_error(response, payload)
      rows_from(payload)
    rescue Error, ArgumentError
      raise
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise RequestError, "Unable to connect to Neo4j Aura (#{error.class})"
    end

    private
      attr_reader :base_uri, :username, :password, :database, :open_timeout, :read_timeout

      def self.credential(name)
        Rails.application.credentials.dig(:neo4j, name)
      end

      def credential(name)
        self.class.credential(name)
      end

      def setting(name)
        ENV[ENVIRONMENT_VARIABLES.fetch(name)].presence || credential(name)
      end

      def require_setting(value, name)
        return value unless value.to_s.strip.empty?

        environment_variable = ENVIRONMENT_VARIABLES.fetch(name.to_sym)
        raise ConfigurationError,
          "Missing Neo4j #{name}; set #{environment_variable} or add neo4j.#{name} to Rails credentials"
      end

      def normalize_uri(connection_uri)
        value = require_setting(connection_uri, "connection_uri")
        uri = URI.parse(value)

        unless %w[neo4j+s https].include?(uri.scheme) && uri.host.present?
          raise ConfigurationError,
            "Neo4j connection_uri must use neo4j+s:// or https:// and include a host"
        end

        URI::HTTPS.build(host: uri.host, port: uri.scheme == "https" ? uri.port : 443)
      rescue URI::InvalidURIError
        raise ConfigurationError, "Neo4j connection_uri is malformed"
      end

      def validate_database(value)
        database_name = require_setting(value, "database")
        return database_name if DATABASE_NAME_PATTERN.match?(database_name)

        raise ConfigurationError,
          "Neo4j database may contain only letters, numbers, dots, underscores, and hyphens"
      end

      def endpoint_uri
        URI.join(base_uri.to_s, "/db/#{database}/query/v2")
      end

      def build_request(statement, parameters)
        request = Net::HTTP::Post.new(endpoint_uri)
        request.basic_auth(username, password)
        request["Accept"] = "application/json"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(statement: statement, parameters: parameters)
        request
      end

      def perform_request(request)
        uri = request.uri

        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: true,
          open_timeout: open_timeout,
          read_timeout: read_timeout
        ) do |http|
          http.request(request)
        end
      end

      def parse_response(response)
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise ResponseError, "Neo4j Aura returned an invalid JSON response"
      end

      def raise_response_error(response, payload)
        if response.code.to_i == 401
          raise AuthenticationError, "Neo4j Aura authentication failed"
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise RequestError, "Neo4j Aura request failed with HTTP #{response.code}"
        end

        errors = Array(payload["errors"])
        return if errors.empty?

        error = errors.first
        code = error.is_a?(Hash) ? error["code"] : nil
        message = code.present? ? "Neo4j query failed (#{code})" : "Neo4j query failed"
        raise QueryError, message
      end

      def rows_from(payload)
        data = payload["data"]
        unless data.is_a?(Hash) && data["fields"].is_a?(Array) && data["values"].is_a?(Array)
          raise ResponseError, "Neo4j Aura response did not contain query data"
        end

        fields = data["fields"]
        data["values"].map do |values|
          unless values.is_a?(Array) && values.length == fields.length
            raise ResponseError, "Neo4j Aura returned malformed query rows"
          end

          fields.zip(values).to_h
        end
      end
  end
end
