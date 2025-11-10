#!/usr/bin/env ruby

require 'bundler/setup'
require 'rma/payment/gateway'

# Configure the gateway
Rma::Payment::Gateway.configure do |config|
  config.base_url = ENV['RMA_BASE_URL'] || 'https://your-rma-gateway-url.com'
  config.rsa_key_path = ENV['RMA_RSA_KEY_PATH'] || 'config/rma_private_key.pem'
  config.beneficiary_id = ENV['RMA_BENEFICIARY_ID'] || 'your_beneficiary_id'
  config.payment_description = ENV['RMA_PAYMENT_DESCRIPTION'] || 'Payment for services'
end

# Initialize client
client = Rma::Payment::Gateway::Client.new

def process_payment(client, order_no, amount, email, bank_id, account_no, otp)
  puts "🚀 Starting payment process for Order: #{order_no}"
  puts "💰 Amount: #{amount} BTN"
  puts "📧 Email: #{email}"
  puts "-" * 50

  begin
    # Step 1: Authorization
    puts "\n1️⃣  Requesting payment authorization..."
    auth_response = client.authorization.call(order_no, amount, email)
    transaction_id = auth_response["bfs_bfsTxnId"]
    
    puts "✅ Authorization successful!"
    puts "   Transaction ID: #{transaction_id}"
    puts "   Response Code: #{auth_response['bfs_responseCode']}"

    # Step 2: Account Inquiry
    puts "\n2️⃣  Verifying bank account..."
    inquiry_response = client.account_inquiry.call(transaction_id, bank_id, account_no)
    
    puts "✅ Account verified!"
    puts "   Account Holder: #{inquiry_response['bfs_remitterName']}"
    puts "   Account Number: #{inquiry_response['bfs_remitterAccNo']}"
    puts "   📱 OTP sent to registered mobile number"

    # Step 3: Debit Request
    puts "\n3️⃣  Completing payment with OTP..."
    debit_response = client.debit_request.call(transaction_id, otp)
    
    puts "🎉 Payment completed successfully!"
    puts "   Transaction ID: #{debit_response['bfs_bfsTxnId']}"
    puts "   Amount Debited: #{debit_response['bfs_txnAmount']} BTN"
    puts "   Order Number: #{debit_response['bfs_orderNo']}"
    
    return debit_response

  rescue Rma::Payment::Gateway::InvalidParameterError => e
    puts "❌ Invalid parameters: #{e.message}"
  rescue Rma::Payment::Gateway::AuthenticationError => e
    puts "❌ Authentication failed: #{e.message}"
  rescue Rma::Payment::Gateway::NetworkError => e
    puts "❌ Network error: #{e.message}"
  rescue Rma::Payment::Gateway::Error => e
    puts "❌ Payment failed: #{e.message}"
  end
end

# Example usage
if __FILE__ == $0
  # Sample payment data
  order_no = "ORDER#{Time.now.to_i}"
  amount = 100.50
  email = "customer@example.com"
  bank_id = "1010"  # Bank of Bhutan
  account_no = "12345678"
  otp = "123456"  # In real scenario, customer provides this

  result = process_payment(client, order_no, amount, email, bank_id, account_no, otp)
  
  if result
    puts "\n🎊 Payment processing completed successfully!"
  else
    puts "\n💥 Payment processing failed!"
  end
end