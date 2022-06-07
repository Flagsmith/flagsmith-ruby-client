# frozen_string_literal: true

module Flagsmith
  class ClientError < StandardError; end

  class APIError < StandardError; end

  class FeatureStateNotFound < StandardError; end
end
