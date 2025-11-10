# frozen_string_literal: true

require_relative "gateway/version"
require_relative "gateway/configuration"
require_relative "gateway/client"
require_relative "gateway/utils"
require_relative "gateway/errors"
require_relative "gateway/authorization"
require_relative "gateway/account_inquiry"
require_relative "gateway/debit_request"

module Rma
  module Payment
    module Gateway
      class Error < StandardError; end

      class << self
        attr_accessor :configuration
      end

      def self.configure
        self.configuration ||= Configuration.new
        yield(configuration)
      end

      def self.client
        Client.new(configuration)
      end
    end
  end
end
