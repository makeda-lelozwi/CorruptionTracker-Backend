class PublicEntitiesController < ApplicationController
  EXTERNAL_ID_PATTERN = /\A[a-z][a-z0-9_-]*:[a-zA-Z0-9._:-]+\z/
  INDEX_PAGE_SIZE = 5

  before_action :set_entry

  def index
    @query = params[:q].to_s.strip
    entities = repository.all(label: @entry.label, query: @query).map do |entity|
      entity.merge("path" => PublicEntityCatalog.member_path(@entry.label, entity.fetch("externalId")))
    end
    @total_entities = entities.length
    @total_pages = (@total_entities.to_f / INDEX_PAGE_SIZE).ceil
    @page = params[:page].to_i.clamp(1, [ @total_pages, 1 ].max)
    @entities = entities.slice((@page - 1) * INDEX_PAGE_SIZE, INDEX_PAGE_SIZE) || []
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
    @event_trail = PublicEventTrail.new(
      repository.event_trail(external_id: external_id)
    ).call if @entry.label == "Event"
    @person_profile_insights = PublicPersonProfileBuilder.new(
      person: result.entity,
      facts: result.facts
    ).call if @entry.label == "Person"
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
