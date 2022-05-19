# # frozen_string_literal: true
#
# module FlagsmithEngine
#   # Available Flagsmith Functions
#   module InstanceMethods
#     def environment_flags
#       responsible_manager.get_flags
#     end
#
#     def identity_flags(*args)
#       responsible_manager.get_flags(*args)
#     end
#
#     def feature_enabled?(feature_name, default: false)
#       flag = environment_flags[feature_name]
#       return default if flag.nil?
#
#       flag.enabled?
#     end
#
#     def feature_enabled_for_identity?(feature_name, user_id, default: false)
#       flag = identity_flags(user_id)[feature_name]
#       return default if flag.nil?
#
#       flag.enabled?
#     end
#
#     def feature_value(feature_name, user_id = nil, default: nil)
#       flag = identity_flags(user_id)[feature_name]
#       return default if flag.nil?
#
#       flag.value
#     end
#
#     alias get_environment_flags environment_flags
#
#     private
#
#     def responsible_manager
#       return environment if environment.is_a? FlagsmithEngine::Environment
#
#       api_client
#     end
#   end
# end
