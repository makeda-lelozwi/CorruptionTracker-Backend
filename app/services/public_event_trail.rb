class PublicEventTrail
  Stage = Data.define(:label, :events, :current)

  def initialize(rows)
    @rows = rows
  end

  def call
    return [] if rows.empty?

    history = unique_events(rows.first["history"])
    return [] if history.empty?

    stages = history.each_with_index.map do |event, index|
      current = index == history.length - 1
      Stage.new(
        label: history_label(index, history.length, current),
        events: [ event ],
        current: current
      )
    end

    history_ids = history.pluck(:external_id)
    future = Array(rows.first["future"])
      .compact
      .filter_map { |event| normalize_event(event, depth: event["depth"]) }
      .reject { |event| history_ids.include?(event[:external_id]) }
      .group_by { |event| event[:depth].to_i }

    future.keys.sort.each do |depth|
      events = future.fetch(depth).uniq { |event| event[:external_id] }.sort_by { |event| event[:name].downcase }
      stages << Stage.new(label: future_label(depth), events: events, current: false)
    end

    stages.length > 1 ? stages : []
  end

  private
    attr_reader :rows

    def unique_events(events)
      Array(events)
        .filter_map { |event| normalize_event(event) }
        .uniq { |event| event[:external_id] }
    end

    def normalize_event(event, depth: nil)
      return unless event.is_a?(Hash) && event["externalId"].present?

      external_id = event.fetch("externalId")
      {
        external_id: external_id,
        name: event["name"].presence || external_id,
        path: PublicEntityCatalog.member_path("Event", external_id),
        depth: depth
      }
    end

    def history_label(index, length, current)
      return "Current event" if current
      return "Original spark" if index.zero? && length > 1

      "Earlier event"
    end

    def future_label(depth)
      depth.to_i == 1 ? "Next" : "Two steps later"
    end
end
