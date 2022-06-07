module Web
  module Views
    module Home
      class Index
        include Web::View

        def form
          form_for :flagsmith, '/', method: :get do
            h3 'Identify as a User'
            div style: 'margin-bottom: 1em;' do
              label :identifier
              text_field :identifier
            end
            p '... with an optional user trait'
            div style: 'margin-bottom: 1em;' do
              label :trait_key
              text_field :trait_key
            end
            div style: 'margin-bottom: 1em;' do
              label :trait_value
              text_field :trait_value
            end
            div { submit 'Identify!' }
          end
        end
      end
    end
  end
end
