class PersonGraphNarrative
  def initialize(rows)
    @rows = rows
  end

  def call
    return "" if rows.empty?

    [
      employment_sentence,
      allegations_sentence,
      associations_sentence,
      events_sentence
    ].compact.join(" ")
  end

  private
    attr_reader :rows

    def person_name
      rows.first.fetch("personName")
    end

    def employment_sentence
      row = row_for("WORKS_FOR")
      return unless row

      organisation = connected_name(row)
      position = row.dig("r", "properties", "position") ||
        row.dig("p", "properties", "title")

      if position.present?
        "According to the source material represented in the current dataset, " \
          "#{person_name} is identified as #{position} within #{with_article(organisation)}."
      else
        "According to the source material represented in the current dataset, " \
          "#{person_name} is identified as working for #{with_article(organisation)}."
      end
    end

    def allegations_sentence
      allegations = rows_for("SUBJECT_OF").map { |row| connected_name(row) }
      return if allegations.empty?

      "#{person_name} is the subject of allegations concerning #{allegations.to_sentence}."
    end

    def associations_sentence
      memberships = rows_for("ALLEGED_MEMBER_OF").map { |row| connected_name(row) }
      associates = rows_for("ASSOCIATE_OF").map { |row| connected_name(row) }
      clauses = []

      if memberships.any?
        clauses << "alleged in the source material to be a member of #{memberships.to_sentence}"
      end

      if associates.any?
        clauses << "recorded as associated with #{associates.to_sentence}"
      end

      return if clauses.empty?

      "#{person_name} is also #{clauses.to_sentence(last_word_connector: " and ")}."
    end

    def events_sentence
      events = rows_for("INVOLVES").filter_map do |row|
        connected_name(row) if row["connectedNodeType"] == "Event"
      end
      return if events.empty?

      noun = events.one? ? "event" : "events"
      event_names = events.map { |event| "“#{event}”" }
      "The dataset further connects #{person_name} to the #{noun} #{event_names.to_sentence}."
    end

    def row_for(relationship)
      rows.find { |row| row["relationship"] == relationship }
    end

    def rows_for(relationship)
      rows.select { |row| row["relationship"] == relationship }
    end

    def connected_name(row)
      properties = row.fetch("connectedNode").fetch("properties")

      properties["name"] ||
        properties["title"] ||
        properties["externalId"] ||
        row.fetch("connectedNodeType")
    end

    def with_article(name)
      name.match?(/\Athe\b/i) ? name : "the #{name}"
    end
end
