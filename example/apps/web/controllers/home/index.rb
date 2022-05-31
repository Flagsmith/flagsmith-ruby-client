module Web
  module Controllers
    module Home
      class Index
        include Web::Action

        expose :identifier, :show_button, :button_color

        def call(params)
          @identifier = params.get(:flagsmith, :identifier)

          if @identifier.nil? || @identifier.blank?
            # Get the default flags for the current environment
            flags = $flagsmith.get_environment_flags
            @show_button = flags.is_feature_enabled("secret_button")
            @button_data = JSON.parse(flags.get_feature_value("secret_button"))["colour"]
          else
            trait_key = params.get(:flagsmith, :trait_key)
            trait_value = params.get(:flagsmith, :trait_value)
            traits = trait_key.nil? ? nil : { trait_key: trait_value }

            # Get the flags for an identity, including the provided trait which will be
            # persisted to the API for future requests.
            identity_flags = $flagsmith.get_identity_flags(identifier, traits)
            @show_button = identity_flags.is_feature_enabled('secret_button')
            @button_color = JSON.parse(identity_flags.get_feature_value('secret_button'))['colour']
          end
        end
      end
    end
  end
end
