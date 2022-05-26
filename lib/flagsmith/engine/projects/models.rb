# frozen_string_literal: true

module Flagsmith
  module Engine
    # ProjectModel
    class Project
      attr_reader :id, :name, :organisation
      attr_accessor :segments, :hide_disabled_flags

      def initialize(id:, name:, organisation:, hide_disabled_flags:, segments: [])
        @id = id
        @name = name
        @hide_disabled_flags = hide_disabled_flags
        @organisation = organisation
        @segments = segments
      end

      class << self
        def build(json)
          segments = json.fetch(:segments, []).map { |s| Flagsmith::Engine::Segment.build(s) }

          new(
            **json.slice(:id, :name, :hide_disabled_flags)
                  .merge(organisation: Flagsmith::Engine::Organisation.build(json[:organisation]))
                  .merge(segments: segments)
          )
        end
      end
    end
  end
end
