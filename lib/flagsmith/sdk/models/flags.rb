# frozen_string_literal: true

module Flagsmith
  module Flags
    class NotFound < StandardError; end

    # Base data class for the flag entity
    class BaseFlag
      include Comparable

      attr_reader :enabled, :value, :default

      def initialize(enabled:, value:, default:)
        @enabled = enabled
        @value = value
        @default = default
      end

      def enabled?
        enabled
      end

      alias is_default default
    end

    # Flag class to be used by default handler logic
    class DefaultFlag < BaseFlag
      def initialize(enabled:, value:)
        super(enabled: enabled, value: value, default: true)
      end
    end

    # 'live' Flag class as returned by API or local evaluation
    class Flag < BaseFlag
      attr_reader :feature_name, :feature_id, :reason

      def initialize(feature_name:, enabled:, value:, feature_id:, reason: nil)
        super(enabled: enabled, value: value, default: false)
        @feature_name = feature_name
        @feature_id = feature_id
        @reason = reason
      end

      def <=>(other)
        feature_name <=> other.feature_name
      end

      def [](key)
        to_h[key]
      end

      def to_h
        {
          feature_id: feature_id,
          feature_name: feature_name,
          value: value,
          enabled: enabled,
          default: default,
          reason: reason
        }
      end

      class << self
        def from_feature_state_model(feature_state_model, identity_id)
          new(
            enabled: feature_state_model.enabled,
            value: feature_state_model.get_value(identity_id),
            feature_name: feature_state_model.feature.name,
            feature_id: feature_state_model.feature.id
          )
        end

        def from_api(json_flag_data)
          new(
            enabled: json_flag_data[:enabled],
            value: json_flag_data.fetch(:feature_state_value) { json_flag_data[:value] },
            feature_name: json_flag_data.dig(:feature, :name),
            feature_id: json_flag_data.dig(:feature, :id)
          )
        end
      end
    end

    # Implementation of a class to hold a collection of flags.
    # Implements methods for working with the list to avoid requesting flags for each feature evaluation.
    class Collection
      include Enumerable

      attr_reader :flags, :default_flag_handler, :analytics_processor, :offline_handler

      def initialize(flags = {}, analytics_processor: nil, default_flag_handler: nil, offline_handler: nil)
        @flags = flags
        @default_flag_handler = default_flag_handler
        @analytics_processor = analytics_processor
        @offline_handler = offline_handler
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

      def get_flag_from_offline_handler(key)
        @offline_handler.environment.feature_states.each do |feature_state|
          return Flag.from_feature_state_model(feature_state, nil) if key == Flagsmith::Flags::Collection.normalize_key(feature_state.feature.name)
        end
        raise Flagsmith::Flags::NotFound,
              "Feature does not exist: #{key}, offline_handler did not find a flag in this case."
      end

      # Get a specific flag given the feature name.
      # :param feature_name: the name of the feature to retrieve the flag for.
      # :return: BaseFlag object.
      # :raises FlagsmithClientError: if feature doesn't exist
      def get_flag(feature_name)
        key = Flagsmith::Flags::Collection.normalize_key(feature_name)

        flag = flags.fetch(key)
        @analytics_processor.track_feature(flag.feature_name) if @analytics_processor && flag.feature_id
        flag
      rescue KeyError
        return get_flag_from_offline_handler(key) if @offline_handler

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
              Flagsmith::Flags::Flag.from_api(json_flag)
          }

          new(
            json_data.each_with_object({}, &to_flag_object),
            **args
          )
        end

        def from_evaluation_result(evaluation_result, **args)
          to_flag_object = lambda { |flag_result, acc|
            flagsmith_id = flag_result.dig(:metadata, :flagsmith_id)

            if flagsmith_id.nil?
              raise Flagsmith::ClientError,
                    "FlagResult metadata.flagsmith_id is missing for feature \"#{flag_result[:name]}\". " \
                    'This indicates a bug in the SDK, please report it.'
            end

            acc[normalize_key(flag_result[:name])] = Flagsmith::Flags::Flag.new(
              feature_name: flag_result[:name],
              enabled: flag_result[:enabled],
              value: flag_result[:value],
              feature_id: flagsmith_id,
              reason: flag_result[:reason]
            )
          }

          new(
            evaluation_result[:flags].each_value.each_with_object({}, &to_flag_object),
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
