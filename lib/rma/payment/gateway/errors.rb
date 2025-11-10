# frozen_string_literal: true

module Rma
  module Payment
    module Gateway
      class Error < StandardError; end
      class ConfigurationError < Error; end
      class InvalidParameterError < Error; end
      class AuthenticationError < Error; end
      class NetworkError < Error; end
      class APIError < Error; end
    end
  end
end
