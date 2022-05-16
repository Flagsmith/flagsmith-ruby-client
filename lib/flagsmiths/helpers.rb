# frozen_string_literal: true

module Flagsmiths
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
  end
end

# export const retryFetch = (
#     url: string,
#     fetchOptions = {},
#     retries = 3,
#     retryDelay = 1000,
#     timeout: number
# ): Promise<Response> => {
#     return new Promise((resolve, reject) => {
#         // check for timeout
#         if (timeout) setTimeout(() => reject('error: timeout'), timeout)
#
#         const wrapper = (n: number) => {
#             fetch(url, fetchOptions)
#                 .then(res => resolve(res))
#                 .catch(async err => {
#                     if (n > 0) {
#                         await delay(retryDelay)
#                         wrapper(--n)
#                     } else {
#                         reject(err)
#                     }
#                 })
#         }
#
#         wrapper(retries)
#     })
# }
