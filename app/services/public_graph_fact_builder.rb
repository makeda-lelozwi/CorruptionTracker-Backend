class PublicGraphFactBuilder
  Result = Data.define(:entity, :facts, :lanes)
  Template = Data.define(:lane, :sentence, :direction)

  LANE_ORDER = [
    "Testimony and sources",
    "Evidence",
    "Allegations and complaints",
    "Communication",
    "Roles and affiliations",
    "Events and causality",
    "Procurement and ownership",
    "Other connections"
  ].freeze

  RELATIONSHIP_LANES = {
    "DISCUSSES" => "Testimony and sources",
    "GIVEN_BY" => "Testimony and sources",
    "SUPPORTS" => "Evidence",
    "EVIDENCES" => "Evidence",
    "CONTRADICTS" => "Evidence",
    "TRANSMITTED" => "Evidence",
    "NAMES_AS_COMPLAINANT" => "Evidence",
    "SUBJECT_OF" => "Allegations and complaints",
    "RAISED" => "Allegations and complaints",
    "BROUGHT_COMPLAINT" => "Allegations and complaints",
    "RECEIVED_COMPLAINT" => "Allegations and complaints",
    "SENT_INFORMATION" => "Communication",
    "SENT_TO" => "Communication",
    "INFORMED" => "Communication",
    "WARNED" => "Communication",
    "WARNED_ABOUT" => "Communication",
    "COMMUNICATED_WITH" => "Communication",
    "WORKS_FOR" => "Roles and affiliations",
    "HOLDS_POSITION" => "Roles and affiliations",
    "ASSOCIATE_OF" => "Roles and affiliations",
    "ASSOCIATED_WITH" => "Roles and affiliations",
    "ALLEGED_MEMBER_OF" => "Roles and affiliations",
    "EXECUTIVE_OVERSIGHT_OF" => "Roles and affiliations",
    "LED_TO" => "Events and causality",
    "INVOLVES" => "Events and causality",
    "INVESTIGATED" => "Events and causality",
    "DISBANDED" => "Events and causality",
    "MURDERED" => "Events and causality",
    "VICTIM" => "Events and causality",
    "OWNS" => "Procurement and ownership",
    "AWARDED" => "Procurement and ownership",
    "AWARDED_TO" => "Procurement and ownership",
    "BUYS_FROM" => "Procurement and ownership",
    "SELLS_TO" => "Procurement and ownership"
  }.freeze

  # Wording is selected by the complete graph pattern because a relationship
  # type can mean something different between different kinds of nodes.
  TEMPLATES = {
    [ "Testimony", "DISCUSSES", "Allegation" ] => Template.new(lane: "Testimony and sources", sentence: "%{source} discusses the allegation “%{target}”.", direction: :forward),
    [ "Event", "LED_TO", "Allegation" ] => Template.new(lane: "Events and causality", sentence: "The dataset records %{source} as leading to the allegation “%{target}”.", direction: :forward),
    [ "Person", "WORKS_FOR", "Organisation" ] => Template.new(lane: "Roles and affiliations", sentence: "%{source} is recorded as working for %{target}.", direction: :forward),
    [ "Event", "INVOLVES", "Person" ] => Template.new(lane: "Events and causality", sentence: "%{target} is recorded as involved in %{source}.", direction: :reverse),
    [ "Person", "ASSOCIATE_OF", "Person" ] => Template.new(lane: "Roles and affiliations", sentence: "%{source} is recorded as associated with %{target}.", direction: :forward),
    [ "Evidence", "SUPPORTS", "Allegation" ] => Template.new(lane: "Evidence", sentence: "%{source} is recorded as supporting the allegation “%{target}”.", direction: :forward),
    [ "Person", "SUBJECT_OF", "Allegation" ] => Template.new(lane: "Allegations and complaints", sentence: "%{source} is recorded as the subject of the allegation “%{target}”.", direction: :forward),
    [ "Person", "USED_INTERMEDIARY", "Person" ] => Template.new(lane: "Other connections", sentence: "%{source} is recorded as having used %{target} as an intermediary.", direction: :forward),
    [ "Testimony", "DISCUSSES", "Event" ] => Template.new(lane: "Testimony and sources", sentence: "%{source} discusses the event “%{target}”.", direction: :forward),
    [ "Event", "LED_TO", "Event" ] => Template.new(lane: "Events and causality", sentence: "%{source} led to %{target}.", direction: :forward),
    [ "Organisation", "INVESTIGATED", "Event" ] => Template.new(lane: "Events and causality", sentence: "%{source} is recorded as having investigated %{target}.", direction: :forward),
    [ "Organisation", "RECEIVED_COMPLAINT", "Event" ] => Template.new(lane: "Allegations and complaints", sentence: "%{source} is recorded as having received a complaint connected with %{target}.", direction: :forward),
    [ "Organisation", "SUBJECT_OF", "Allegation" ] => Template.new(lane: "Allegations and complaints", sentence: "%{source} is recorded as the subject of the allegation “%{target}”.", direction: :forward),
    [ "Person", "ALLEGED_MEMBER_OF", "Organisation" ] => Template.new(lane: "Roles and affiliations", sentence: "%{source} is alleged in the dataset to be a member of %{target}.", direction: :forward),
    [ "Person", "MURDERED", "Event" ] => Template.new(lane: "Events and causality", sentence: "%{source} is connected to %{target} through a relationship recorded as MURDERED.", direction: :forward),
    [ "Person", "SENT_INFORMATION", "Event" ] => Template.new(lane: "Communication", sentence: "%{source} is recorded as having sent information connected with %{target}.", direction: :forward),
    [ "Testimony", "GIVEN_BY", "Person" ] => Template.new(lane: "Testimony and sources", sentence: "%{source} is recorded as having been given by %{target}.", direction: :forward),
    [ "Allegation", "BROUGHT_COMPLAINT", "Organisation" ] => Template.new(lane: "Allegations and complaints", sentence: "%{source} is recorded as a complaint brought to %{target}.", direction: :forward),
    [ "Person", "RAISED", "Event" ] => Template.new(lane: "Events and causality", sentence: "%{source} raised the %{target}.", direction: :forward),
    [ "Event", "INFORMED", "Person" ] => Template.new(lane: "Communication", sentence: "%{source} is recorded as having informed %{target}.", direction: :forward),
    [ "Event", "INVESTIGATED", "Person" ] => Template.new(lane: "Events and causality", sentence: "%{target} is recorded as investigated in %{source}.", direction: :reverse),
    [ "Event", "VICTIM", "Person" ] => Template.new(lane: "Events and causality", sentence: "%{target} was the victim in %{source}.", direction: :reverse)
  }.freeze

  APPROVED_METADATA_KEYS = %w[role position note reason status].freeze

  def initialize(rows)
    @rows = rows
  end

  def call
    return if rows.empty?

    entity = entity_from(rows.first.fetch("subject"), subject_label)
    facts = rows.filter_map { |row| fact_from(row) }
      .sort_by { |fact| [ LANE_ORDER.index(fact[:lane]), fact[:sentence] ] }

    Result.new(
      entity: entity,
      facts: facts,
      lanes: facts.group_by { |fact| fact[:lane] }
    )
  end

  private
    attr_reader :rows

    def subject_label
      labels = rows.first.fetch("subject").fetch("labels")
      PublicEntityCatalog::LABELS.find { |label| labels.include?(label) }
    end

    def fact_from(row)
      relationship = row["relationship"]
      return unless relationship

      source = entity_from(row.fetch("source"), row.fetch("sourceLabel"))
      target = entity_from(row.fetch("target"), row.fetch("targetLabel"))
      relationship_type = row.fetch("relationshipType")
      pattern = [ source[:label], relationship_type, target[:label] ]
      template = TEMPLATES[pattern]
      properties = relationship.fetch("properties")

      {
        id: relationship.fetch("elementId"),
        sentence: sentence_for(template, source, target, relationship_type),
        lane: template&.lane || RELATIONSHIP_LANES.fetch(relationship_type, "Other connections"),
        direction: template&.direction || :forward,
        source: source,
        target: target,
        description: humanized_description(properties["description"]),
        quote: properties["quote"],
        page: properties["page"],
        metadata: properties.slice(*APPROVED_METADATA_KEYS).compact,
        relationship_type: relationship_type,
        pattern: pattern
      }
    end

    def entity_from(node, label)
      properties = node.fetch("properties")
      external_id = properties.fetch("externalId")

      {
        id: node.fetch("elementId"),
        label: label,
        external_id: external_id,
        name: properties["name"] || properties["title"] || external_id,
        description: properties["description"] || properties["summary"],
        path: PublicEntityCatalog.member_path(label, external_id)
      }
    end

    def sentence_for(template, source, target, relationship_type)
      return format(template.sentence, source: source[:name], target: target[:name]) if template

      relationship = relationship_type.to_s.downcase.tr("_", " ")
      target_name = target[:label] == "Allegation" ? "the allegation of #{target[:name]}" : target[:name]
      sentence = "#{source[:name]} #{relationship} #{target_name}"
      sentence.match?(/[.!?]\z/) ? sentence : "#{sentence}."
    end

    def humanized_description(description)
      return if description.blank?

      text = description.to_s.squish.sub(/\A\p{Ll}/) { |letter| letter.upcase }
      text.match?(/[.!?]\z/) ? text : "#{text}."
    end
end
