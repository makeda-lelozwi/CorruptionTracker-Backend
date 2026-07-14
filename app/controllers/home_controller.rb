class HomeController < ApplicationController
  def show
    @query = params[:q].to_s.strip
    rows_by_label = PublicEntityRepository.new.grouped(query: @query).index_by { |row| row.fetch("publicLabel") }

    @sections = PublicEntityCatalog::ENTRIES.map do |entry|
      entities = Array(rows_by_label.dig(entry.label, "entities"))
      {
        entry: entry,
        count: entities.length,
        entities: entities.first(6).map { |entity| entity.merge("path" => PublicEntityCatalog.member_path(entry.label, entity.fetch("externalId"))) }
      }
    end
  rescue Neo4j::Client::Error => error
    Rails.logger.error("Public evidence index failed: #{error.class}")
    @sections = []
    @load_error = true
    render :show, status: :bad_gateway
  end
end
