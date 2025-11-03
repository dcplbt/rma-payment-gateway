# frozen_string_literal: true

require "dotenv/load" # Load environment variables

module Rma
  module Payment
    module Gateway
      # Configuration class for RMA Payment Gateway.
      # Handles all configuration options required for the RMA Payment Gateway client.
      #
      # @example
      #   config = Rma::Payment::Gateway::Configuration.new
      #   config.base_url = 'https://api.example.com'
      #   config.rsa_key_path = '/path/to/rsa_key.pem'
      #   config.beneficiary_id = 'YOUR_BENEFICIARY_ID'
      class Configuration
        attr_accessor :base_url, :rsa_key_path, :beneficiary_id, :payment_description, :timeout, :open_timeout

        def initialize
          @base_url = ENV["RMA_BASE_URL"]
          @rsa_key_path = ENV["RMA_RSA_KEY_PATH"]
          @beneficiary_id = ENV["RMA_BENEFICIARY_ID"]
          @payment_description = ENV["RMA_PAYMENT_DESCRIPTION"]
          @timeout = 30
          @open_timeout = 10
        end

        def valid?
          required_fields.all? { |field| !send(field).nil? && !send(field).to_s.empty? }
        end

        def required_fields
          %i[base_url rsa_key_path beneficiary_id payment_description]
        end

        def missing_fields
          required_fields.reject { |field| !send(field).nil? && !send(field).to_s.empty? }
        end
      end
    end
  end
end
