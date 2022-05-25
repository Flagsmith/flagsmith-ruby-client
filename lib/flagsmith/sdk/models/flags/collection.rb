# frozen_string_literal: true

module Flagsmith
  module Flags
    class NotFound < StandardError; end

    # Flag Collection
    class Collection
      include Enumerable

      attr_reader :flags, :default_flag_handler, :analytics_processor

      def initialize(flags = {}, analytics_processor: nil, default_flag_handler: nil)
        @flags = flags
        @default_flag_handler = default_flag_handler
        @analytics_processor = analytics_processor
      end

      def each(&block)
        flags.each { |item| block&.call(item) || item }
      end

      def to_a
        @flags.values || []
      end
      alias all_flags to_a

      # Check whether a given feature is enabled.
      # :param feature_name: the name of the feature to check if enabled.
      # :return: Boolean representing the enabled state of a given feature.
      # :raises FlagsmithClientError: if feature doesn't exist
      def feature_enabled?(feature_name)
        get_flag(feature_name).enabled?
      end
      alias is_feature_enabled feature_enabled?

      # Get the value of a particular feature.
      # :param feature_name: the name of the feature to retrieve the value of.
      # :return: the value of the given feature.
      # :raises FlagsmithClientError: if feature doesn't exist
      def feature_value(feature_name)
        get_flag(feature_name).value
      end
      alias get_feature_value feature_value

      # Get a specific flag given the feature name.
      # :param feature_name: the name of the feature to retrieve the flag for.
      # :return: BaseFlag object.
      # :raises FlagsmithClientError: if feature doesn't exist
      def get_flag(feature_name)
        key = Flagsmith::Flags::Collection.normalize_key(feature_name)
        flag = flags.fetch(key)
        @analytics_processor.track_feature(flag.feature_id) if @analytics_processor && flag.feature_id
        flag
      rescue KeyError
        return @default_flag_handler.call(feature_name) if @default_flag_handler

        raise Flagsmith::Flags::NotFound,
              "Feature does not exist: #{key}, implement default_flag_handler to handle this case."
      end

      def [](key)
        key.is_a?(Integer) ? to_a[key] : get_flag(key)
      end

      def length
        to_a.length
      end

      def inspect
        "<##{self.class}:#{object_id.to_s(8)} flags=#{@flags}>"
      end

      class << self
        def from_api(json_data, **args)
          to_flag_object = lambda { |json_flag, acc|
            acc[normalize_key(json_flag.dig(:feature, :name))] =
              Flagsmith::Flag.from_api(json_flag)
          }

          new(
            json_data.each_with_object({}, &to_flag_object),
            **args
          )
        end

        def from_feature_state_models(feature_states, identity_id: nil, **args)
          to_flag_object = lambda { |feature_state, acc|
            acc[normalize_key(feature_state.feature.name)] =
              Flagsmith::Flag.from_feature_state_model(feature_state, identity_id)
          }

          new(
            feature_states.each_with_object({}, &to_flag_object),
            **args
          )
        end

        def normalize_key(key)
          key.to_s.downcase
        end
      end
    end
  end
end
