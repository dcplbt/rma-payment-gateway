# frozen_string_literal: true

module Rma
  module Payment
    module Gateway
      module Services
        class AccountInquiry
          def initialize(client)
            @client = client
          end

          def call(transaction_id, bank_id, account_no)
            # Implementation here
            {}
          end
        end
      end
    end
  end
end