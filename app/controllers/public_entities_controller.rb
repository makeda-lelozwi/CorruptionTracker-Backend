class PublicEntitiesController < ApplicationController
  EXTERNAL_ID_PATTERN = /\A[a-z][a-z0-9_-]*:[a-zA-Z0-9._:-]+\z/

  before_action :set_entry

  def index
    @query = params[:q].to_s.strip
    @entities = repository.all(label: @entry.label, query: @query).map do |entity|
      entity.merge("path" => PublicEntityCatalog.member_path(@entry.label, entity.fetch("externalId")))
    end
  rescue Neo4j::Client::Error => error
    render_neo4j_error(error)
  end

  def show
    external_id = params[:external_id].to_s
    return head :not_found unless EXTERNAL_ID_PATTERN.match?(external_id)

    result = PublicGraphFactBuilder.new(
      repository.find(label: @entry.label, external_id: external_id)
    ).call
    return head :not_found unless result

    @entity = result.entity
    @facts_by_lane = result.lanes
    @graph = PublicEntityGraph.new(entity: result.entity, facts: result.facts).call
  rescue Neo4j::Client::Error => error
    render_neo4j_error(error)
  end

  private
    def set_entry
      @entry = PublicEntityCatalog.fetch(params[:label])
    rescue KeyError
      head :not_found
    end

    def repository
      @repository ||= PublicEntityRepository.new
    end

    def render_neo4j_error(error)
      Rails.logger.error("Public evidence request failed: #{error.class}")
      render :error, status: :bad_gateway
    end
end
