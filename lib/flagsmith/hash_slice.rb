# frozen_string_literal: true

module Flagsmith
  # Hash#slice was added in ruby version 2.5
  module HashSlice
    def slice(*keys)
      select { |key, _value| keys.include?(key) }
    end
  end
end

Hash.include Flagsmith::HashSlice if RUBY_VERSION < '2.5.0'
