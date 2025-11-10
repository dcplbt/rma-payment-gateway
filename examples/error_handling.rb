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

class PaymentProcessor
  attr_reader :client, :logger

  def initialize
    @client = Rma::Payment::Gateway::Client.new
    @logger = Logger.new(STDOUT)
  end

  def process_payment_with_comprehensive_error_handling(order_no, amount, email, bank_id, account_no, otp)
    logger.info("Starting payment process for order: #{order_no}")

    begin
      # Step 1: Authorization with error handling
      transaction_id = authorize_payment(order_no, amount, email)
      return nil unless transaction_id

      # Step 2: Account verification with error handling
      account_verified = verify_account(transaction_id, bank_id, account_no)
      return nil unless account_verified

      # Step 3: Complete payment with error handling
      complete_payment(transaction_id, otp)

    rescue => e
      logger.error("Unexpected error in payment process: #{e.message}")
      logger.error(e.backtrace.join("\n"))
      nil
    end
  end

  private

  def authorize_payment(order_no, amount, email)
    logger.info("Authorizing payment...")
    
    response = client.authorization.call(order_no, amount, email)
    transaction_id = response["bfs_bfsTxnId"]
    
    logger.info("Authorization successful: #{transaction_id}")
    transaction_id

  rescue Rma::Payment::Gateway::ConfigurationError => e
    logger.error("Configuration error: #{e.message}")
    logger.error("Please check your RMA gateway configuration")
    notify_admin("Configuration Error", e)
    nil

  rescue Rma::Payment::Gateway::InvalidParameterError => e
    logger.error("Invalid parameters: #{e.message}")
    logger.error("Order: #{order_no}, Amount: #{amount}, Email: #{email}")
    
    # Provide specific feedback based on the error
    if e.message.include?('email')
      logger.error("Email validation failed")
    elsif e.message.include?('amount')
      logger.error("Amount validation failed")
    end
    nil

  rescue Rma::Payment::Gateway::AuthenticationError => e
    logger.error("Authentication failed: #{e.message}")
    logger.error("Check your RSA key and beneficiary ID")
    notify_admin("Authentication Error", e)
    nil

  rescue Rma::Payment::Gateway::NetworkError => e
    logger.error("Network error during authorization: #{e.message}")
    
    # Implement retry logic for network errors
    retry_authorization(order_no, amount, email, 3)

  rescue Rma::Payment::Gateway::APIError => e
    logger.error("API error during authorization: #{e.message}")
    logger.error("Response code: #{e.response_code}")
    
    case e.response_code
    when '02'
      logger.error("Invalid beneficiary - contact RMA support")
    when '99'
      logger.error("System error - try again later")
    end
    nil

  rescue Rma::Payment::Gateway::Error => e
    logger.error("Gateway error during authorization: #{e.message}")
    nil
  end

  def verify_account(transaction_id, bank_id, account_no)
    logger.info("Verifying account...")
    
    response = client.account_inquiry.call(transaction_id, bank_id, account_no)
    account_name = response["bfs_remitterName"]
    
    logger.info("Account verified: #{account_name}")
    true

  rescue Rma::Payment::Gateway::InvalidParameterError => e
    logger.error("Invalid account details: #{e.message}")
    
    if e.message.include?('bank_id')
      logger.error("Invalid bank code: #{bank_id}")
    elsif e.message.include?('account_no')
      logger.error("Invalid account number: #{account_no}")
    end
    false

  rescue Rma::Payment::Gateway::APIError => e
    logger.error("Account verification failed: #{e.message}")
    
    case e.response_code
    when '03'
      logger.error("Invalid transaction ID")
    when '04'
      logger.error("Account not found or inactive")
    end
    false

  rescue Rma::Payment::Gateway::Error => e
    logger.error("Error during account verification: #{e.message}")
    false
  end

  def complete_payment(transaction_id, otp)
    logger.info("Completing payment...")
    
    response = client.debit_request.call(transaction_id, otp)
    
    logger.info("Payment completed successfully!")
    logger.info("Amount: #{response['bfs_txnAmount']} BTN")
    response

  rescue Rma::Payment::Gateway::APIError => e
    logger.error("Payment completion failed: #{e.message}")
    
    case e.response_code
    when '05'
      logger.error("Invalid OTP provided")
    when '06'
      logger.error("OTP has expired - request new OTP")
    when '04'
      logger.error("Insufficient funds in account")
    end
    nil

  rescue Rma::Payment::Gateway::Error => e
    logger.error("Error during payment completion: #{e.message}")
    nil
  end

  def retry_authorization(order_no, amount, email, max_retries)
    retries = 0
    
    while retries < max_retries
      retries += 1
      sleep(2 ** retries) # Exponential backoff
      
      logger.info("Retrying authorization (attempt #{retries}/#{max_retries})...")
      
      begin
        response = client.authorization.call(order_no, amount, email)
        logger.info("Authorization successful on retry #{retries}")
        return response["bfs_bfsTxnId"]
      rescue Rma::Payment::Gateway::NetworkError => e
        logger.warn("Retry #{retries} failed: #{e.message}")
        next if retries < max_retries
        logger.error("All retry attempts failed")
      end
    end
    
    nil
  end

  def notify_admin(error_type, exception)
    # In a real application, you would send email, Slack notification, etc.
    logger.error("ADMIN NOTIFICATION: #{error_type}")
    logger.error("Exception: #{exception.class.name}")
    logger.error("Message: #{exception.message}")
    logger.error("Time: #{Time.current}")
  end
end

# Example usage with comprehensive error handling
if __FILE__ == $0
  processor = PaymentProcessor.new
  
  # Test with various error scenarios
  test_cases = [
    {
      name: "Valid Payment",
      order_no: "ORDER#{Time.now.to_i}",
      amount: 100.50,
      email: "customer@example.com",
      bank_id: "1010",
      account_no: "12345678",
      otp: "123456"
    },
    {
      name: "Invalid Email",
      order_no: "ORDER#{Time.now.to_i}",
      amount: 100.50,
      email: "invalid-email",
      bank_id: "1010",
      account_no: "12345678",
      otp: "123456"
    },
    {
      name: "Invalid Amount",
      order_no: "ORDER#{Time.now.to_i}",
      amount: -100,
      email: "customer@example.com",
      bank_id: "1010",
      account_no: "12345678",
      otp: "123456"
    }
  ]

  test_cases.each do |test_case|
    puts "\n" + "="*60
    puts "Testing: #{test_case[:name]}"
    puts "="*60
    
    result = processor.process_payment_with_comprehensive_error_handling(
      test_case[:order_no],
      test_case[:amount],
      test_case[:email],
      test_case[:bank_id],
      test_case[:account_no],
      test_case[:otp]
    )
    
    if result
      puts "✅ Test passed: Payment processed successfully"
    else
      puts "❌ Test failed: Payment processing failed"
    end
  end
end