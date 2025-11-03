# frozen_string_literal: true

require "uri"
require "securerandom"

module Rma
  module Payment
    module Gateway
      # Authorization class for RMA Payment Gateway.
      # Handles authentication and authorization for the RMA Payment Gateway client.
      #
      # @example
      #   auth = Rma::Payment::Gateway::Authorization.new(client)
      #   auth.call(order_no, amount, email)
      #
      # @param client [Rma::Payment::Gateway::Client] Client instance
      class DebitRequest
        attr_reader :client, :transaction_id, :otp

        def initialize(client)
          @client = client
        end

        # Fetch debit request
        # Returns the debit request string
        def call(transaction_id, otp)
          @transaction_id = transaction_id
          @otp = otp
          response = client.post(body: debit_request_body)

          validate_debit_request_response!(response)

          response["result"]
        rescue StandardError => e
          raise AuthenticationError, "Failed to fetch debit request: #{e.message}"
        end

        private

        def debit_request_body
          params = {
            bfs_bfsTxnId: transaction_id,
            bfs_remitterOtp: otp,
            bfs_benfId: client.config.beneficiary_id,
            bfs_msgType: "DR"
          }

          # Convert to URL-encoded format
          URI.encode_www_form(params)
        end

        def validate_debit_request_response!(response)
          unless response.is_a?(Hash) && response["result"]["bfs_responseCode"] == "00"
            error_detail = response["result"]["bfs_responseDesc"] || "Unknown error"
            raise AuthenticationError, "Debit request failed: #{error_detail}"
          end

          return if response["result"]

          raise AuthenticationError, "No response data in response"
        end
      end
    end
  end
end
