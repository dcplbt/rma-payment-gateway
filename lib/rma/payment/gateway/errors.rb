# frozen_string_literal: true

module Rma
  module Payment
    module Gateway
      class Error < StandardError; end

      class ConfigurationError < Error; end

      class AuthenticationError < Error; end

      class InvalidParameterError < Error
        attr_reader :response_code, :response_detail

        def initialize(message, response_code: 422, response_detail: "Invalid parameters")
          super(message)
          @response_code = response_code
          @response_detail = response_detail
        end
      end

      class APIError < Error
        attr_reader :response_code, :response_message, :response_description, :response_detail

        def initialize(message, response_code: 422, response_message: "Invalid parameters",
                       response_description: "Invalid parameters", response_detail: "Invalid parameters")
          super(message)
          @response_code = response_code
          @response_message = response_message
          @response_description = response_description
          @response_detail = response_detail
        end
      end

      class NetworkError < Error; end

      class SignatureError < Error; end

      class TransactionError < APIError; end
    end
  end
end
