# frozen_string_literal: true

module Flagsmith
  module SDK
    # Util functions
    module Intervals
      # @return [Thread] return loop thread reference
      # rubocop:disable Naming/AccessorMethodName
      def set_interval(delay)
        Thread.new do
          loop do
            yield if block_given?
            sleep delay
          end
        end
      end
      # rubocop:enable Naming/AccessorMethodName

      def clear_interval(thread)
        thread.kill
      end
    end
  end
end
