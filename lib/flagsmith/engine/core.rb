# frozen_string_literal: true

require 'semantic'
require 'securerandom'

require_relative 'environments/models'
require_relative 'features/models'
require_relative 'identities/models'
require_relative 'organisations/models'
require_relative 'projects/models'
require_relative 'segments/evaluator'
require_relative 'segments/models'
require_relative 'utils/hash_func'
require_relative 'evaluation/mappers'
require_relative 'evaluation/core'

module Flagsmith
  module Engine
    # Flags engine methods
    # NOTE: This class is kept for backwards compatibility but no longer contains
    # the old model-based evaluation methods. Use the context-based evaluation
    # via Flagsmith::Engine::Evaluation::Core.get_evaluation_result instead.
    class Engine
      include Flagsmith::Engine::Segments::Evaluator
    end
  end
end
