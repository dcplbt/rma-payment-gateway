# frozen_string_literal: true

module Rma
  module Payment
    module Gateway
      module Services
        class Authorization
          def initialize(client)
            @client = client
          end

          def call(order_no, amount, email)
            # Implementation here
            {}
          end
        end
      end
    end
  end
end