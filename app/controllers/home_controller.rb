class HomeController < ApplicationController
  INDEX_LABELS = %w[Allegation Event Person Organisation].freeze

  def show
    @query = params[:q].to_s.strip
    repository = PublicEntityRepository.new
    rows_by_label = repository.grouped.index_by { |row| row.fetch("publicLabel") }
    filtered_rows_by_label = filter_rows(rows_by_label, @query)

    @overview_sections = build_sections(rows_by_label)
    @sections = build_sections(filtered_rows_by_label)
    @testimonies = Array(rows_by_label.dig("Testimony", "entities"))
      .sort_by { |testimony| testimony["date"].to_s }
      .map { |testimony| decorate_testimony(testimony) }

    testimonies = Array(filtered_rows_by_label.dig("Testimony", "entities"))
    @latest_testimony = decorate_testimony(testimonies.max_by { |testimony| testimony["date"].to_s })
  rescue Neo4j::Client::Error => error
    Rails.logger.error("Public evidence index failed: #{error.class}")
    @sections = []
    @load_error = true
    render :show, status: :bad_gateway
  end


  private
    def build_sections(rows_by_label)
      INDEX_LABELS.map { |label| PublicEntityCatalog.fetch(label) }.map do |entry|
        entities = Array(rows_by_label.dig(entry.label, "entities"))
        {
          entry: entry,
          count: entities.length,
          entities: entities.map { |entity| entity.merge("path" => PublicEntityCatalog.member_path(entry.label, entity.fetch("externalId"))) }
        }
      end
    end

    def filter_rows(rows_by_label, query)
      return rows_by_label if query.blank?

      normalized_query = query.downcase
      rows_by_label.transform_values do |row|
        row.merge(
          "entities" => Array(row["entities"]).select do |entity|
            %w[externalId name title].any? do |key|
              entity[key].to_s.downcase.include?(normalized_query)
            end
          end
        )
      end
    end

    def decorate_testimony(testimony)
      return unless testimony

      testimony.merge(
        "path" => PublicEntityCatalog.member_path("Testimony", testimony.fetch("externalId")),
        "allegations" => Array(testimony["allegations"]).filter_map do |allegation|
          next if allegation["externalId"].blank?

          allegation.merge("path" => PublicEntityCatalog.member_path("Allegation", allegation.fetch("externalId")))
        end
      )
    end
end
