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
      #   auth.authorize
      #
      # @param client [Rma::Payment::Gateway::Client] Client instance
      class Authorization
        attr_reader :client, :order_no, :amount, :email

        def initialize(client)
          @client = client
        end

        # Fetch authorization token
        # Returns the authorization response
        def call(order_no, amount, email)
          @order_no = order_no
          @amount = amount
          @email = email
          validate_authorization_request!
          response = client.post(body: authorization_request_body)

          validate_authorization_response!(response)

          response["result"]
        rescue StandardError => e
          raise AuthenticationError, "Failed to authorize: #{e.message}"
        end

        private

        def authorization_request_body
          params = {
            bfs_benfTxnTime: Utils.generate_timestamp,
            bfs_orderNo: order_no,
            bfs_benfBankCode: "01",
            bfs_txnCurrency: "BTN",
            bfs_txnAmount: Utils.format_amount(amount),
            bfs_remitterEmail: email,
            bfs_paymentDesc: client.config.payment_description,
            bfs_benfId: client.config.beneficiary_id,
            bfs_msgType: "AR",
            bfs_version: "5.0"
          }

          # Convert to URL-encoded format
          URI.encode_www_form(params)
        end

        def validate_authorization_request!
          raise InvalidParameterError, "Order number is required" if order_no.nil? || order_no.empty?
          raise InvalidParameterError, "Amount is required" if amount.nil? || amount.empty?
          raise InvalidParameterError, "Email is required" if email.nil? || email.empty?
          raise InvalidParameterError, "Amount must be a number" unless Utils.valid_amount?(amount)
          raise InvalidParameterError, "Email must be a valid email" unless Utils.valid_email?(email)
        end

        def validate_authorization_response!(response)
          unless response.is_a?(Hash) && response["result"]["bfs_responseCode"] == "00"
            error_detail = response["result"]["bfs_responseDesc"] || "Unknown error"
            raise AuthenticationError, "Authorization failed: #{error_detail}"
          end

          return if response["result"]

          raise AuthenticationError, "No response data in response"
        end
      end
    end
  end
end
