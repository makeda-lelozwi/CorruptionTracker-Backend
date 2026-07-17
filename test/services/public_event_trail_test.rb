require "test_helper"

class PublicEventTrailTest < ActiveSupport::TestCase
  test "builds stages from the original spark through two future depths" do
    stages = PublicEventTrail.new([ {
      "history" => [
        event("event:spark", "Original complaint"),
        event("event:briefing", "Police briefing"),
        event("event:current", "Current event")
      ],
      "future" => [
        event("event:next-b", "Outcome B", depth: 1),
        event("event:next-a", "Outcome A", depth: 1),
        event("event:later", "Follow-up", depth: 2)
      ]
    } ]).call

    assert_equal [ "Original spark", "Earlier event", "Current event", "Next", "Two steps later" ], stages.map(&:label)
    assert_equal [ "Outcome A", "Outcome B" ], stages[3].events.pluck(:name)
    assert stages[2].current
    assert_equal "/events/event:later", stages.last.events.first[:path]
  end

  test "does not show a trail containing only the current event" do
    stages = PublicEventTrail.new([ {
      "history" => [ event("event:current", "Current event") ],
      "future" => [ nil ]
    } ]).call

    assert_empty stages
  end

  private
    def event(external_id, name, depth: nil)
      { "externalId" => external_id, "name" => name, "depth" => depth }
    end
end
