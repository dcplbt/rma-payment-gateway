# Usage Guide

This guide provides practical examples and best practices for integrating the RMA Payment Gateway into your Ruby application.

## Table of Contents

- [Quick Start](#quick-start)
- [Rails Integration](#rails-integration)
- [Sinatra Integration](#sinatra-integration)
- [Common Use Cases](#common-use-cases)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Quick Start

### 1. Installation

Add to your Gemfile:

```ruby
gem 'rma-payment-gateway'
```

Run:

```bash
bundle install
```

### 2. Configuration

Create a `.env` file:

```env
RMA_BASE_URL=https://your-rma-gateway-url.com
RMA_RSA_KEY_PATH=/path/to/rsa_private_key.pem
RMA_BENEFICIARY_ID=your_beneficiary_id
RMA_PAYMENT_DESCRIPTION=Payment for services
```

### 3. Basic Usage

```ruby
require 'rma/payment/gateway'

# Initialize client
client = Rma::Payment::Gateway::Client.new

# Process payment
begin
  # Step 1: Authorization
  auth_response = client.authorization.call("ORDER123", 100.50, "customer@email.com")
  transaction_id = auth_response["bfs_bfsTxnId"]
  
  # Step 2: Account Inquiry (customer provides bank details)
  inquiry_response = client.account_inquiry.call(transaction_id, "1010", "12345678")
  
  # Step 3: Debit Request (customer provides OTP)
  debit_response = client.debit_request.call(transaction_id, "123456")
  
  puts "Payment successful!"
rescue Rma::Payment::Gateway::Error => e
  puts "Payment failed: #{e.message}"
end
```

## Rails Integration

### Configuration

Create an initializer `config/initializers/rma_payment_gateway.rb`:

```ruby
Rma::Payment::Gateway.configure do |config|
  config.base_url = ENV['RMA_BASE_URL']
  config.rsa_key_path = Rails.root.join('config', 'rma_private_key.pem').to_s
  config.beneficiary_id = ENV['RMA_BENEFICIARY_ID']
  config.payment_description = ENV['RMA_PAYMENT_DESCRIPTION']
  config.timeout = 30
  config.open_timeout = 10
end
```

### Service Object Pattern

Create a payment service `app/services/rma_payment_service.rb`:

```ruby
class RmaPaymentService
  attr_reader :client, :order, :errors

  def initialize(order)
    @order = order
    @client = Rma::Payment::Gateway::Client.new
    @errors = []
  end

  def authorize_payment
    response = client.authorization.call(
      order.order_number,
      order.total_amount,
      order.customer_email
    )
    
    order.update!(
      rma_transaction_id: response["bfs_bfsTxnId"],
      payment_status: 'authorized'
    )
    
    response
  rescue Rma::Payment::Gateway::Error => e
    @errors << e.message
    Rails.logger.error("RMA Authorization failed: #{e.message}")
    nil
  end

  def verify_account(bank_id, account_number)
    response = client.account_inquiry.call(
      order.rma_transaction_id,
      bank_id,
      account_number
    )
    
    order.update!(
      customer_bank_id: bank_id,
      customer_account_number: account_number,
      customer_account_name: response["bfs_remitterName"],
      payment_status: 'account_verified'
    )
    
    response
  rescue Rma::Payment::Gateway::Error => e
    @errors << e.message
    Rails.logger.error("RMA Account Inquiry failed: #{e.message}")
    nil
  end

  def complete_payment(otp)
    response = client.debit_request.call(
      order.rma_transaction_id,
      otp
    )
    
    order.update!(
      payment_status: 'completed',
      paid_at: Time.current
    )
    
    response
  rescue Rma::Payment::Gateway::Error => e
    @errors << e.message
    Rails.logger.error("RMA Debit Request failed: #{e.message}")
    nil
  end
end
```

### Controller Example

```ruby
class PaymentsController < ApplicationController
  before_action :set_order

  def new
    # Show payment form
  end

  def authorize
    service = RmaPaymentService.new(@order)
    
    if service.authorize_payment
      redirect_to account_verification_path(@order), notice: 'Payment authorized'
    else
      flash[:error] = service.errors.join(', ')
      render :new
    end
  end

  def verify_account
    service = RmaPaymentService.new(@order)
    
    if service.verify_account(params[:bank_id], params[:account_number])
      redirect_to otp_verification_path(@order), notice: 'OTP sent to your mobile'
    else
      flash[:error] = service.errors.join(', ')
      render :account_form
    end
  end

  def complete
    service = RmaPaymentService.new(@order)
    
    if service.complete_payment(params[:otp])
      redirect_to order_path(@order), notice: 'Payment completed successfully'
    else
      flash[:error] = service.errors.join(', ')
      render :otp_form
    end
  end

  private

  def set_order
    @order = Order.find(params[:order_id])
  end
end
```

### Background Job Example

For handling payment processing asynchronously:

```ruby
class ProcessRmaPaymentJob < ApplicationJob
  queue_as :payments

  def perform(order_id, step, params = {})
    order = Order.find(order_id)
    service = RmaPaymentService.new(order)

    case step
    when 'authorize'
      service.authorize_payment
    when 'verify_account'
      service.verify_account(params[:bank_id], params[:account_number])
    when 'complete'
      service.complete_payment(params[:otp])
    end
  rescue StandardError => e
    Rails.logger.error("RMA Payment Job failed: #{e.message}")
    # Send notification to admin
    AdminMailer.payment_failed(order, e.message).deliver_later
  end
end
```

## Sinatra Integration

### Configuration

```ruby
require 'sinatra'
require 'rma/payment/gateway'

configure do
  Rma::Payment::Gateway.configure do |config|
    config.base_url = ENV['RMA_BASE_URL']
    config.rsa_key_path = File.join(settings.root, 'config', 'rma_private_key.pem')
    config.beneficiary_id = ENV['RMA_BENEFICIARY_ID']
    config.payment_description = ENV['RMA_PAYMENT_DESCRIPTION']
  end
end

helpers do
  def rma_client
    @rma_client ||= Rma::Payment::Gateway::Client.new
  end
end
```

### Routes Example

```ruby
post '/payments/authorize' do
  begin
    response = rma_client.authorization.call(
      params[:order_no],
      params[:amount].to_f,
      params[:email]
    )
    
    session[:transaction_id] = response["bfs_bfsTxnId"]
    redirect '/payments/account-verification'
  rescue Rma::Payment::Gateway::Error => e
    flash[:error] = e.message
    redirect '/payments/new'
  end
end

post '/payments/verify-account' do
  begin
    response = rma_client.account_inquiry.call(
      session[:transaction_id],
      params[:bank_id],
      params[:account_number]
    )
    
    session[:account_name] = response["bfs_remitterName"]
    redirect '/payments/otp-verification'
  rescue Rma::Payment::Gateway::Error => e
    flash[:error] = e.message
    redirect '/payments/account-verification'
  end
end

post '/payments/complete' do
  begin
    response = rma_client.debit_request.call(
      session[:transaction_id],
      params[:otp]
    )
    
    flash[:success] = 'Payment completed successfully'
    redirect '/orders/confirmation'
  rescue Rma::Payment::Gateway::Error => e
    flash[:error] = e.message
    redirect '/payments/otp-verification'
  end
end
```

## Common Use Cases

### 1. E-commerce Checkout

```ruby
class CheckoutService
  def process_payment(cart, customer)
    client = Rma::Payment::Gateway::Client.new
    
    # Step 1: Create order
    order = create_order(cart, customer)
    
    # Step 2: Authorize payment
    auth_response = client.authorization.call(
      order.number,
      order.total,
      customer.email
    )
    
    order.update!(transaction_id: auth_response["bfs_bfsTxnId"])
    
    # Return order for customer to complete payment
    order
  end
end
```

### 2. Subscription Payments

```ruby
class SubscriptionPaymentService
  def charge_subscription(subscription)
    client = Rma::Payment::Gateway::Client.new
    
    # Generate unique order number
    order_no = "SUB-#{subscription.id}-#{Time.now.to_i}"
    
    # Authorize payment
    response = client.authorization.call(
      order_no,
      subscription.plan.price,
      subscription.user.email
    )
    
    # Store transaction for later completion
    subscription.payments.create!(
      transaction_id: response["bfs_bfsTxnId"],
      amount: subscription.plan.price,
      status: 'pending'
    )
  end
end
```

### 3. Refund Handling

```ruby
class RefundService
  def process_refund(payment)
    # Note: Refunds may need to be handled through RMA's admin interface
    # This is a placeholder for your refund logic
    
    payment.update!(
      status: 'refund_requested',
      refund_requested_at: Time.current
    )
    
    # Notify admin to process refund manually
    AdminMailer.refund_requested(payment).deliver_later
  end
end
```

## Best Practices

### 1. Error Handling

Always handle specific exceptions:

```ruby
begin
  client.authorization.call(order_no, amount, email)
rescue Rma::Payment::Gateway::InvalidParameterError => e
  # Handle validation errors - show to user
  flash[:error] = "Invalid input: #{e.message}"
rescue Rma::Payment::Gateway::NetworkError => e
  # Handle network errors - retry or show maintenance message
  flash[:error] = "Service temporarily unavailable. Please try again."
rescue Rma::Payment::Gateway::Error => e
  # Handle all other errors
  flash[:error] = "Payment failed. Please contact support."
  logger.error("RMA Payment Error: #{e.message}")
end
```

### 2. Logging

Log transactions with masked sensitive data:

```ruby
def log_transaction(step, transaction_id, response)
  Rails.logger.info({
    step: step,
    transaction_id: transaction_id,
    response_code: response["bfs_responseCode"],
    timestamp: Time.current
  }.to_json)
end
```

### 3. Idempotency

Prevent duplicate payments:

```ruby
def authorize_payment(order)
  return if order.rma_transaction_id.present?
  
  # Proceed with authorization
  response = client.authorization.call(...)
  order.update!(rma_transaction_id: response["bfs_bfsTxnId"])
end
```

### 4. Validation

Validate inputs before API calls:

```ruby
def validate_payment_params(amount, email)
  errors = []
  
  unless Rma::Payment::Gateway::Utils.valid_amount?(amount)
    errors << "Invalid amount"
  end
  
  unless Rma::Payment::Gateway::Utils.valid_email?(email)
    errors << "Invalid email"
  end
  
  raise ArgumentError, errors.join(', ') if errors.any?
end
```

## Troubleshooting

### Common Issues

#### 1. Configuration Error

**Error:** `Missing required configuration fields`

**Solution:**
```ruby
# Check configuration
config = Rma::Payment::Gateway.configuration
puts config.missing_fields
```

#### 2. Network Timeout

**Error:** `Network error: execution expired`

**Solution:**
```ruby
# Increase timeout
Rma::Payment::Gateway.configure do |config|
  config.timeout = 60
  config.open_timeout = 20
end
```

#### 3. Invalid OTP

**Error:** `Debit request failed: Invalid OTP`

**Solution:**
- Verify OTP is entered correctly
- Check if OTP has expired
- Restart the payment flow if needed

#### 4. Transaction Not Found

**Error:** `Invalid transaction`

**Solution:**
- Verify transaction ID is stored correctly
- Check if transaction has expired
- Ensure all three steps use the same transaction ID

### Debug Mode

Enable detailed logging:

```ruby
# In Rails
Rails.logger.level = :debug

# Log all requests/responses
client = Rma::Payment::Gateway::Client.new
response = client.authorization.call(...)
Rails.logger.debug("RMA Response: #{response.inspect}")
```

## Support

For additional help:

- GitHub Issues: https://github.com/dcplbt/rma-payment-gateway/issues
- Email: tashii.dendupp@gmail.com

