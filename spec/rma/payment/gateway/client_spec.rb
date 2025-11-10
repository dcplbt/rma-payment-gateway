require 'spec_helper'

RSpec.describe Rma::Payment::Gateway::Client do
  let(:client) { described_class.new }

  before do
    Rma::Payment::Gateway.configure do |config|
      config.base_url = 'https://test-gateway.example.com'
      config.rsa_key_path = 'spec/fixtures/test_private_key.pem'
      config.beneficiary_id = 'TEST_BENEFICIARY'
      config.payment_description = 'Test Payment'
    end
  end

  describe '#authorization' do
    it 'returns authorization service' do
      expect(client.authorization).to be_a(Rma::Payment::Gateway::Services::Authorization)
    end
  end

  describe '#account_inquiry' do
    it 'returns account inquiry service' do
      expect(client.account_inquiry).to be_a(Rma::Payment::Gateway::Services::AccountInquiry)
    end
  end

  describe '#debit_request' do
    it 'returns debit request service' do
      expect(client.debit_request).to be_a(Rma::Payment::Gateway::Services::DebitRequest)
    end
  end
end