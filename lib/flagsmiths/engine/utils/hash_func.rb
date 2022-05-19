# frozen_string_literal: true

require 'digest'

module Flagsmiths
  module Engine
    module Utils
      # HashFunction
      module HashFunc
        # Given a list of object ids, get a floating point number between 0 (inclusive) and
        # 100 (exclusive) based on the hash of those ids. This should give the same value
        # every time for any list of ids.
        #
        # :param object_ids: list of object ids to calculate the hash for
        # :param iterations: num times to include each id in the generated string to hash
        # :return: (float) number between 0 (inclusive) and 100 (exclusive)
        def get_hashed_percentage_for_object_ids(object_ids, iterations = 1)
          to_hash = (object_ids.map(&:to_s) * iterations).flatten.join(',')

          hashed_value = Digest::MD5.hexdigest(to_hash.encode('utf-8'))
          hashed_value_as_int = hashed_value.unpack1('s>')[0]
          value = ((hashed_value_as_int % 9999).to_f / 9998) * 100

          # since we want a number between 0 (inclusive) and 100 (exclusive), in the
          # unlikely case that we get the exact number 100, we call the method again
          # and increase the number of iterations to ensure we get a different result
          return get_hashed_percentage_for_object_ids(object_ids, iterations + 1) if value == 100

          value
        end
      end
    end
  end
end
