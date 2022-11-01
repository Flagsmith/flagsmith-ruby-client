# frozen_string_literal: true

module Flagsmith
  module Segments
    class Segment
      attr_reader :id, :name
      
      def initialize(id:, name:)
        @id = id
        @name = name
      end
    end
  end
end
