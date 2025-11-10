require 'spec_helper'

RSpec.describe Rma::Payment::Gateway::Services::Authorization do
  let(:service) { described_class.new }

  before do
    Rma::Payment::Gateway.configure do |config|
      config.base_url = 'https://test-gateway.example.com'
      config.rsa_key_path = 'spec/fixtures/test_private_key.pem'
      config.beneficiary_id = 'TEST_BENEFICIARY'
      config.payment_description = 'Test Payment'
    end
  end

  describe '#call', :vcr do
    context 'with valid parameters' do
      it 'returns successful response' do
        stub_request(:post, "https://test-gateway.example.com/api/authorization")
          .to_return(
            status: 200,
            body: {
              bfs_bfsTxnId: 'TXN123456789',
              bfs_responseCode: '00',
              bfs_responseDesc: 'Success'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        response = service.call('ORDER123', 100.50, 'test@example.com')

        expect(response['bfs_bfsTxnId']).to eq('TXN123456789')
        expect(response['bfs_responseCode']).to eq('00')
      end
    end

    context 'with invalid parameters' do
      it 'raises InvalidParameterError for invalid email' do
        expect {
          service.call('ORDER123', 100.50, 'invalid-email')
        }.to raise_error(Rma::Payment::Gateway::InvalidParameterError)
      end

      it 'raises InvalidParameterError for invalid amount' do
        expect {
          service.call('ORDER123', -100, 'test@example.com')
        }.to raise_error(Rma::Payment::Gateway::InvalidParameterError)
      end
    end
  end
end