# frozen_string_literal: true

require "uri"
require "securerandom"

module Rma
  module Payment
    module Gateway
      # Account Inquiry class for RMA Payment Gateway.
      # Handles account inquiry for the RMA Payment Gateway client.
      #
      # @example
      #   auth = Rma::Payment::Gateway::AccountInquiry.new(client)
      #   auth.call(transaction_id, bank_id, account_no)
      #
      # @param client [Rma::Payment::Gateway::Client] Client instance
      class AccountInquiry
        attr_reader :client, :transaction_id, :bank_id, :account_no

        def initialize(client)
          @client = client
        end

        # Fetch account inquiry
        # Returns the account inquiry response
        def call(transaction_id, bank_id, account_no)
          @transaction_id = transaction_id
          @bank_id = bank_id
          @account_no = account_no
          response = client.post(
            body: account_inquiry_request_body
          )

          validate_account_inquiry_response!(response)

          response["result"]
        rescue StandardError => e
          raise AuthenticationError, "Failed to fetch account inquiry: #{e.message}"
        end

        private

        def account_inquiry_request_body
          params = {
            bfs_bfsTxnId: transaction_id,
            bfs_remitterBankId: bank_id,
            bfs_remitterAccNo: account_no,
            bfs_benfId: client.config.beneficiary_id,
            bfs_msgType: "AE"
          }

          # Convert to URL-encoded format
          URI.encode_www_form(params)
        end

        def validate_account_inquiry_response!(response)
          unless response.is_a?(Hash) && response["result"]["bfs_responseCode"] == "00"
            error_detail = response["result"]["bfs_responseDesc"] || "Unknown error"
            raise AuthenticationError, "Account inquiry failed: #{error_detail}"
          end

          return if response["result"]

          raise AuthenticationError, "No response data in response"
        end
      end
    end
  end
end
