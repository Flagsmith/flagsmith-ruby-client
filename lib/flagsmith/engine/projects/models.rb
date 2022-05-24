# frozen_string_literal: true

module Flagsmith
  module Engine
    # ProjectModel
    class Project
      attr_reader :id, :name, :organisation, :hide_disabled_flags
      attr_accessor :segments

      def initialize(id:, name:, organisation:, hide_disabled_flags:, segments: [])
        @id = id
        @name = name
        @hide_disabled_flags = hide_disabled_flags
        @organisation = organisation
        @segments = segments
      end

      class << self
        def build(json)
          segments = json.fetch('segments', []).map { |s| Flagsmith::Engine::Segment.build(s) }

          new(
            id: json['id'], name: json['name'], hide_disabled_flags: json['hide_disabled_flags'],
            organisation: Flagsmith::Engine::Organisation.build(json['organisation']),
            segments: segments
          )
        end
      end
    end
  end
end
