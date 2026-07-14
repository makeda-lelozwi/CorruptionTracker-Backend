module PublicEntityCatalog
  Entry = Data.define(:label, :singular, :plural, :index_route, :member_route)

  ENTRIES = [
    Entry.new(label: "Testimony", singular: "Testimony", plural: "Testimonies", index_route: :testimonies_path, member_route: :testimony_path),
    Entry.new(label: "Person", singular: "Person", plural: "People", index_route: :people_path, member_route: :person_path),
    Entry.new(label: "Organisation", singular: "Organisation", plural: "Organisations", index_route: :organisations_path, member_route: :organisation_path),
    Entry.new(label: "Event", singular: "Event", plural: "Events", index_route: :events_path, member_route: :event_path),
    Entry.new(label: "Allegation", singular: "Allegation", plural: "Allegations", index_route: :allegations_path, member_route: :allegation_path),
    Entry.new(label: "Evidence", singular: "Evidence", plural: "Evidence", index_route: :evidence_index_path, member_route: :evidence_path)
  ].freeze

  BY_LABEL = ENTRIES.index_by(&:label).freeze
  LABELS = BY_LABEL.keys.freeze

  module_function

  def fetch(label)
    BY_LABEL.fetch(label.to_s)
  end

  def index_path(label)
    Rails.application.routes.url_helpers.public_send(fetch(label).index_route)
  end

  def member_path(label, external_id)
    Rails.application.routes.url_helpers.public_send(
      fetch(label).member_route,
      external_id: external_id
    )
  end
end
