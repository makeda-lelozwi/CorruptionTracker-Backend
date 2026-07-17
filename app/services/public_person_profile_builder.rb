class PublicPersonProfileBuilder
  RELATIONSHIP_ORDER = %w[
    WORKS_FOR
    HOLDS_POSITION
    EXECUTIVE_OVERSIGHT_OF
    OWNS
    ALLEGED_MEMBER_OF
    ASSOCIATE_OF
    ASSOCIATED_WITH
    RELATIVE
  ].freeze

  def initialize(person:, facts:)
    @person = person
    @facts = facts
  end

  def call
    facts.sort_by { |fact| relationship_sort_key(fact) }
      .filter_map { |fact| insight_for(fact) }
      .uniq
  end

  private
    attr_reader :person, :facts

    def insight_for(fact)
      relationship_type = fact[:relationship_type]
      return unless RELATIONSHIP_ORDER.include?(relationship_type)

      related = related_entity(fact)
      return unless related

      case relationship_type
      when "WORKS_FOR"
        employment_sentence(related, fact[:metadata])
      when "HOLDS_POSITION"
        position_sentence(related, fact[:metadata])
      when "EXECUTIVE_OVERSIGHT_OF"
        "#{person[:name]} has executive oversight over #{related[:name]}."
      when "OWNS"
        "#{person[:name]} owns #{related[:name]}."
      when "ALLEGED_MEMBER_OF"
        "#{person[:name]} is allegedly a member of #{related[:name]}."
      when "ASSOCIATE_OF", "ASSOCIATED_WITH"
        "#{person[:name]} is associated with #{related[:name]}."
      when "RELATIVE"
        "#{person[:name]} is related to #{related[:name]}."
      end
    end

    def relationship_sort_key(fact)
      related = related_entity(fact)
      [ RELATIONSHIP_ORDER.index(fact[:relationship_type]) || RELATIONSHIP_ORDER.length, related&.dig(:name).to_s.downcase ]
    end

    def related_entity(fact)
      return fact[:target] if fact[:source][:id] == person[:id]

      fact[:source] if fact[:target][:id] == person[:id]
    end

    def employment_sentence(organisation, metadata)
      position = metadata["position"].presence || metadata["role"].presence
      return "#{person[:name]} works for #{organisation[:name]}." unless position

      "#{person[:name]} works for #{organisation[:name]} as #{position}."
    end

    def position_sentence(organisation, metadata)
      position = metadata["position"].presence || metadata["role"].presence
      return "#{person[:name]} holds a position at #{organisation[:name]}." unless position

      "#{person[:name]} holds the position of #{position} at #{organisation[:name]}."
    end
end
