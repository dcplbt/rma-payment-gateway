# frozen_string_literal: true

module Rma
  module Payment
    module Gateway
      module Services
        class DebitRequest
          def initialize(client)
            @client = client
          end

          def call(transaction_id, otp)
            # Implementation here
            {}
          end
        end
      end
    end
  end
end
