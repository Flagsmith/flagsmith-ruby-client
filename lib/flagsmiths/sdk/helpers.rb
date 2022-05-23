# frozen_string_literal: true

module Flagsmiths
  module SDK
    # Util functions
    module Helpers
      def generate_identities_data(identifier, traits = {})
        {
          identifier: identifier,
          traits: traits.map do |key, value|
            { trait_key: key, trait_value: value }
          end
        }
      end

      def delay(miliseconds)
        sleep miliseconds
      end

      # @return [Thread] return loop thread reference
      # rubocop:disable Naming/AccessorMethodName
      def set_interval(delay)
        Thread.new do
          loop do
            sleep delay
            yield if block_given?
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
