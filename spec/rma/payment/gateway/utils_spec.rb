require 'spec_helper'

RSpec.describe Rma::Payment::Gateway::Utils do
  describe '.valid_email?' do
    it 'returns true for valid emails' do
      expect(described_class.valid_email?('test@example.com')).to be true
      expect(described_class.valid_email?('user.name+tag@domain.co.uk')).to be true
    end

    it 'returns false for invalid emails' do
      expect(described_class.valid_email?('invalid-email')).to be false
      expect(described_class.valid_email?('test@')).to be false
      expect(described_class.valid_email?('@example.com')).to be false
    end
  end

  describe '.valid_amount?' do
    it 'returns true for valid amounts' do
      expect(described_class.valid_amount?(100.50)).to be true
      expect(described_class.valid_amount?(1)).to be true
      expect(described_class.valid_amount?(0.01)).to be true
    end

    it 'returns false for invalid amounts' do
      expect(described_class.valid_amount?(0)).to be false
      expect(described_class.valid_amount?(-100)).to be false
      expect(described_class.valid_amount?('invalid')).to be false
    end
  end

  describe '.valid_bank_code?' do
    it 'returns true for valid bank codes' do
      expect(described_class.valid_bank_code?('1010')).to be true
      expect(described_class.valid_bank_code?('1060')).to be true
    end

    it 'returns false for invalid bank codes' do
      expect(described_class.valid_bank_code?('9999')).to be false
      expect(described_class.valid_bank_code?('invalid')).to be false
    end
  end

  describe '.format_amount' do
    it 'formats amounts to 2 decimal places' do
      expect(described_class.format_amount(100.5)).to eq('100.50')
      expect(described_class.format_amount(100)).to eq('100.00')
    end
  end

  describe '.mask_sensitive' do
    it 'masks sensitive data' do
      expect(described_class.mask_sensitive('1234567890', 2)).to eq('12******90')
      expect(described_class.mask_sensitive('12345', 1)).to eq('1***5')
    end
  end
end