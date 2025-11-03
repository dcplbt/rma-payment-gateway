# frozen_string_literal: true

require "faraday"
require "json"

module Rma
  module Payment
    module Gateway
      # Client class for RMA Payment Gateway.
      # Handles all communication with the RMA Payment Gateway API.
      #
      # @example
      #   client = Rma::Payment::Gateway::Client.new
      #   client.authorization
      #   client.account_inquiry
      #   client.debit_request
      #
      # @param config [Rma::Payment::Gateway::Configuration] Configuration instance
      class Client
        attr_reader :config, :access_token, :private_key

        def initialize(config = nil)
          @config = config || Rma::Payment::Gateway.configuration
          validate_configuration!
        end

        # Authorization methods
        def authorization
          @authorization ||= Authorization.new(self)
        end

        # Account Inquiry methods
        def account_inquiry
          @account_inquiry ||= AccountInquiry.new(self)
        end

        # Debit Request methods
        def debit_request
          @debit_request ||= DebitRequest.new(self)
        end

        # HTTP request methods
        def post(body: {}, headers: {})
          request(:post, body: body, headers: headers)
        end

        def get(headers: {})
          request(:get, headers: headers)
        end

        private

        def validate_configuration!
          raise ConfigurationError, "Configuration is required" if config.nil?
          return if config.valid?

          raise ConfigurationError, "Missing required configuration fields: #{config.missing_fields.join(", ")}"
        end

        def request(method, body: {}, headers: {})
          response = connection.send(method) do |req|
            req.url "/BFSSecure/nvpapi"
            req.headers = build_headers(headers)
            req.body = body.to_query if method == :post && !body.empty?
          end

          handle_response(response)
        rescue Faraday::Error => e
          raise NetworkError, "Network error: #{e.message}"
        end

        def connection
          @connection ||= Faraday.new(url: config.base_url) do |conn|
            conn.request :url_encoded
            conn.response :json, content_type: /\bjson$/
            conn.adapter Faraday.default_adapter
            conn.options.timeout = config.timeout
            conn.options.open_timeout = config.open_timeout
          end
        end

        def build_headers(custom_headers = {})
          headers = { "Content-Type" => "application/x-www-form-urlencoded" }
          headers.merge(custom_headers)
        end

        def handle_response(response)
          case response.status
          when 200..299
            response.body
          when 400..499
            handle_client_error(response)
          when 500..599
            handle_server_error(response)
          else
            raise APIError, "Unexpected response status: #{response.status}"
          end
        end

        def handle_client_error(response)
          body = response.body || {}
          error_message = body["result"]["bfs_responseDesc"] || "Client error"

          raise InvalidParameterError.new(
            error_message,
            response_code: body["result"]["bfs_responseCode"],
            response_detail: body["result"]["bfs_responseDesc"]
          )
        end

        def handle_server_error(response)
          body = response.body || {}
          error_message = body["result"]["bfs_responseDesc"] || "Server error"

          raise APIError.new(
            error_message,
            response_code: body["result"]["bfs_responseCode"],
            response_description: body["result"]["bfs_responseDesc"]
          )
        end
      end
    end
  end
end
