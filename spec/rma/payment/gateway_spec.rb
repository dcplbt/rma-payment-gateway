# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rma::Payment::Gateway do
  describe ".configure" do
    it "allows configuration via block" do
      described_class.configure do |config|
        config.base_url = "https://test.example.com"
        config.beneficiary_id = "TEST123"
      end

      expect(described_class.configuration.base_url).to eq("https://test.example.com")
      expect(described_class.configuration.beneficiary_id).to eq("TEST123")
    end
  end

  describe ".configuration" do
    it "returns configuration instance" do
      expect(described_class.configuration).to be_a(Rma::Payment::Gateway::Configuration)
    end
  end
end
