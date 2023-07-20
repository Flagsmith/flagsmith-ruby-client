# frozen_string_literal: true

module Flagsmith
  module Segments
    # Data class to hold segment information.
    class Segment
      attr_reader :id, :name

      def initialize(id:, name:)
        @id = id
        @name = name
      end
    end
  end
end
