# Code Examples

This document provides practical code examples for common scenarios when using the RMA Payment Gateway gem.

## Table of Contents

- [Basic Examples](#basic-examples)
- [Rails Examples](#rails-examples)
- [Error Handling Examples](#error-handling-examples)
- [Testing Examples](#testing-examples)
- [Advanced Examples](#advanced-examples)

## Basic Examples

### Simple Payment Flow

```ruby
require 'rma/payment/gateway'

# Initialize client
client = Rma::Payment::Gateway::Client.new

# Complete payment flow
def process_payment(order_no, amount, email, bank_id, account_no, otp)
  # Step 1: Authorization
  puts "Authorizing payment..."
  auth_response = client.authorization.call(order_no, amount, email)
  transaction_id = auth_response["bfs_bfsTxnId"]
  puts "✓ Transaction ID: #{transaction_id}"
  
  # Step 2: Account Inquiry
  puts "Verifying account..."
  inquiry_response = client.account_inquiry.call(transaction_id, bank_id, account_no)
  puts "✓ Account holder: #{inquiry_response['bfs_remitterName']}"
  
  # Step 3: Debit Request
  puts "Completing payment..."
  debit_response = client.debit_request.call(transaction_id, otp)
  puts "✓ Payment successful!"
  
  debit_response
end

# Usage
begin
  result = process_payment(
    "ORDER123",
    100.50,
    "customer@email.com",
    "1010",
    "12345678",
    "123456"
  )
  puts "Payment completed: #{result['bfs_orderNo']}"
rescue Rma::Payment::Gateway::Error => e
  puts "Payment failed: #{e.message}"
end
```

### Step-by-Step Payment

```ruby
require 'rma/payment/gateway'

client = Rma::Payment::Gateway::Client.new

# Step 1: Authorization
puts "Enter order number:"
order_no = gets.chomp

puts "Enter amount:"
amount = gets.chomp.to_f

puts "Enter email:"
email = gets.chomp

auth_response = client.authorization.call(order_no, amount, email)
transaction_id = auth_response["bfs_bfsTxnId"]
puts "Authorization successful! Transaction ID: #{transaction_id}"

# Step 2: Account Inquiry
puts "\nEnter bank code (1010-1060):"
bank_id = gets.chomp

puts "Enter account number:"
account_no = gets.chomp

inquiry_response = client.account_inquiry.call(transaction_id, bank_id, account_no)
puts "Account verified: #{inquiry_response['bfs_remitterName']}"
puts "OTP sent to your registered mobile number"

# Step 3: Debit Request
puts "\nEnter OTP:"
otp = gets.chomp

debit_response = client.debit_request.call(transaction_id, otp)
puts "Payment successful!"
puts "Amount: #{debit_response['bfs_txnAmount']} BTN"
```

## Rails Examples

### Payment Model

```ruby
# app/models/payment.rb
class Payment < ApplicationRecord
  belongs_to :order
  belongs_to :user
  
  enum status: {
    pending: 0,
    authorized: 1,
    account_verified: 2,
    completed: 3,
    failed: 4,
    refunded: 5
  }
  
  validates :order_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :transaction_id, uniqueness: true, allow_nil: true
  
  def rma_client
    @rma_client ||= Rma::Payment::Gateway::Client.new
  end
  
  def authorize!
    response = rma_client.authorization.call(
      order.order_number,
      amount,
      user.email
    )
    
    update!(
      transaction_id: response["bfs_bfsTxnId"],
      status: :authorized,
      authorized_at: Time.current
    )
    
    response
  end
  
  def verify_account!(bank_id, account_number)
    response = rma_client.account_inquiry.call(
      transaction_id,
      bank_id,
      account_number
    )
    
    update!(
      bank_id: bank_id,
      account_number: account_number,
      account_holder_name: response["bfs_remitterName"],
      status: :account_verified,
      account_verified_at: Time.current
    )
    
    response
  end
  
  def complete!(otp)
    response = rma_client.debit_request.call(transaction_id, otp)
    
    update!(
      status: :completed,
      completed_at: Time.current
    )
    
    # Update order status
    order.mark_as_paid!
    
    response
  end
end
```

### Payment Controller

```ruby
# app/controllers/payments_controller.rb
class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_payment, only: [:show, :verify_account, :complete]
  
  def new
    @order = Order.find(params[:order_id])
    @payment = @order.payments.build(
      user: current_user,
      amount: @order.total_amount
    )
  end
  
  def create
    @order = Order.find(params[:order_id])
    @payment = @order.payments.build(payment_params)
    @payment.user = current_user
    
    if @payment.save
      begin
        @payment.authorize!
        redirect_to verify_account_payment_path(@payment),
                    notice: 'Payment authorized. Please verify your account.'
      rescue Rma::Payment::Gateway::Error => e
        @payment.update(status: :failed, error_message: e.message)
        flash.now[:error] = "Payment authorization failed: #{e.message}"
        render :new
      end
    else
      render :new
    end
  end
  
  def verify_account
    # Show account verification form
  end
  
  def submit_account
    begin
      @payment.verify_account!(
        params[:bank_id],
        params[:account_number]
      )
      redirect_to complete_payment_path(@payment),
                  notice: 'Account verified. OTP sent to your mobile.'
    rescue Rma::Payment::Gateway::Error => e
      flash.now[:error] = "Account verification failed: #{e.message}"
      render :verify_account
    end
  end
  
  def complete
    # Show OTP form
  end
  
  def submit_otp
    begin
      @payment.complete!(params[:otp])
      redirect_to order_path(@payment.order),
                  notice: 'Payment completed successfully!'
    rescue Rma::Payment::Gateway::Error => e
      flash.now[:error] = "Payment failed: #{e.message}"
      render :complete
    end
  end
  
  private
  
  def set_payment
    @payment = current_user.payments.find(params[:id])
  end
  
  def payment_params
    params.require(:payment).permit(:amount)
  end
end
```

### Payment Service Object

```ruby
# app/services/payment_processor.rb
class PaymentProcessor
  attr_reader :payment, :client, :errors
  
  def initialize(payment)
    @payment = payment
    @client = Rma::Payment::Gateway::Client.new
    @errors = []
  end
  
  def authorize
    validate_authorization!
    
    response = client.authorization.call(
      payment.order.order_number,
      payment.amount,
      payment.user.email
    )
    
    payment.update!(
      transaction_id: response["bfs_bfsTxnId"],
      status: 'authorized'
    )
    
    log_event('authorized', response)
    notify_user('authorization_success')
    
    true
  rescue Rma::Payment::Gateway::Error => e
    handle_error('authorization', e)
    false
  end
  
  def verify_account(bank_id, account_number)
    validate_account_verification!
    
    response = client.account_inquiry.call(
      payment.transaction_id,
      bank_id,
      account_number
    )
    
    payment.update!(
      bank_id: bank_id,
      account_number: account_number,
      account_holder_name: response["bfs_remitterName"],
      status: 'account_verified'
    )
    
    log_event('account_verified', response)
    notify_user('otp_sent')
    
    true
  rescue Rma::Payment::Gateway::Error => e
    handle_error('account_verification', e)
    false
  end
  
  def complete(otp)
    validate_completion!
    
    response = client.debit_request.call(
      payment.transaction_id,
      otp
    )
    
    payment.update!(
      status: 'completed',
      completed_at: Time.current
    )
    
    payment.order.mark_as_paid!
    
    log_event('completed', response)
    notify_user('payment_success')
    send_receipt
    
    true
  rescue Rma::Payment::Gateway::Error => e
    handle_error('completion', e)
    false
  end
  
  private
  
  def validate_authorization!
    raise ArgumentError, "Payment already authorized" if payment.authorized?
    raise ArgumentError, "Invalid amount" unless valid_amount?
  end
  
  def validate_account_verification!
    raise ArgumentError, "Payment not authorized" unless payment.authorized?
  end
  
  def validate_completion!
    raise ArgumentError, "Account not verified" unless payment.account_verified?
  end
  
  def valid_amount?
    Rma::Payment::Gateway::Utils.valid_amount?(payment.amount)
  end
  
  def handle_error(step, error)
    @errors << error.message
    payment.update(
      status: 'failed',
      error_message: error.message,
      failed_at: Time.current
    )
    log_event("#{step}_failed", { error: error.message })
    notify_admin_of_failure(step, error)
  end
  
  def log_event(event, data)
    PaymentLog.create!(
      payment: payment,
      event: event,
      data: data.to_json,
      created_at: Time.current
    )
  end
  
  def notify_user(template)
    PaymentMailer.send(template, payment).deliver_later
  end
  
  def notify_admin_of_failure(step, error)
    AdminMailer.payment_failed(payment, step, error).deliver_later
  end
  
  def send_receipt
    PaymentMailer.receipt(payment).deliver_later
  end
end
```

## Error Handling Examples

### Comprehensive Error Handling

```ruby
def process_payment_with_error_handling(order_no, amount, email)
  client = Rma::Payment::Gateway::Client.new
  
  begin
    response = client.authorization.call(order_no, amount, email)
    { success: true, data: response }
    
  rescue Rma::Payment::Gateway::ConfigurationError => e
    # Configuration issue - needs admin attention
    log_error("Configuration error", e)
    notify_admin(e)
    { success: false, error: "System configuration error. Please contact support." }
    
  rescue Rma::Payment::Gateway::InvalidParameterError => e
    # User input error - show to user
    log_error("Invalid parameters", e)
    { success: false, error: "Invalid input: #{e.message}" }
    
  rescue Rma::Payment::Gateway::AuthenticationError => e
    # Authentication failed - could be temporary
    log_error("Authentication error", e)
    { success: false, error: "Payment authorization failed. Please try again." }
    
  rescue Rma::Payment::Gateway::NetworkError => e
    # Network issue - retry might help
    log_error("Network error", e)
    { success: false, error: "Service temporarily unavailable. Please try again later." }
    
  rescue Rma::Payment::Gateway::APIError => e
    # API error - log and notify
    log_error("API error", e)
    notify_admin(e)
    { success: false, error: "Payment processing error. Please contact support." }
    
  rescue Rma::Payment::Gateway::Error => e
    # Generic error - catch all
    log_error("Unknown error", e)
    notify_admin(e)
    { success: false, error: "An unexpected error occurred. Please contact support." }
  end
end
```

### Retry Logic

```ruby
def authorize_with_retry(order_no, amount, email, max_retries: 3)
  client = Rma::Payment::Gateway::Client.new
  retries = 0
  
  begin
    client.authorization.call(order_no, amount, email)
    
  rescue Rma::Payment::Gateway::NetworkError => e
    retries += 1
    if retries < max_retries
      sleep(2 ** retries) # Exponential backoff
      retry
    else
      raise e
    end
    
  rescue Rma::Payment::Gateway::InvalidParameterError => e
    # Don't retry validation errors
    raise e
  end
end
```

## Testing Examples

### RSpec Examples

```ruby
# spec/services/payment_processor_spec.rb
require 'rails_helper'

RSpec.describe PaymentProcessor do
  let(:user) { create(:user, email: 'test@example.com') }
  let(:order) { create(:order, order_number: 'ORDER123') }
  let(:payment) { create(:payment, user: user, order: order, amount: 100.50) }
  let(:processor) { described_class.new(payment) }
  let(:client) { instance_double(Rma::Payment::Gateway::Client) }
  
  before do
    allow(Rma::Payment::Gateway::Client).to receive(:new).and_return(client)
  end
  
  describe '#authorize' do
    let(:auth_response) do
      {
        "bfs_bfsTxnId" => "TXN123",
        "bfs_responseCode" => "00",
        "bfs_responseDesc" => "Success"
      }
    end
    
    context 'when successful' do
      before do
        allow(client).to receive_message_chain(:authorization, :call)
          .and_return(auth_response)
      end
      
      it 'authorizes the payment' do
        expect(processor.authorize).to be true
        expect(payment.reload.transaction_id).to eq("TXN123")
        expect(payment.status).to eq('authorized')
      end
    end
    
    context 'when authorization fails' do
      before do
        allow(client).to receive_message_chain(:authorization, :call)
          .and_raise(Rma::Payment::Gateway::AuthenticationError, "Failed")
      end
      
      it 'handles the error' do
        expect(processor.authorize).to be false
        expect(processor.errors).to include("Failed")
        expect(payment.reload.status).to eq('failed')
      end
    end
  end
end
```

### Mock Responses

```ruby
# spec/support/rma_helpers.rb
module RmaHelpers
  def mock_rma_authorization(transaction_id: "TXN123")
    {
      "bfs_bfsTxnId" => transaction_id,
      "bfs_responseCode" => "00",
      "bfs_responseDesc" => "Success",
      "bfs_orderNo" => "ORDER123",
      "bfs_txnAmount" => "100.50"
    }
  end
  
  def mock_rma_account_inquiry(name: "John Doe")
    {
      "bfs_bfsTxnId" => "TXN123",
      "bfs_responseCode" => "00",
      "bfs_responseDesc" => "Success",
      "bfs_remitterName" => name,
      "bfs_remitterAccNo" => "12345678"
    }
  end
  
  def mock_rma_debit_request
    {
      "bfs_bfsTxnId" => "TXN123",
      "bfs_responseCode" => "00",
      "bfs_responseDesc" => "Transaction Successful",
      "bfs_txnAmount" => "100.50",
      "bfs_orderNo" => "ORDER123"
    }
  end
end

RSpec.configure do |config|
  config.include RmaHelpers
end
```

## Advanced Examples

### Background Job Processing

```ruby
# app/jobs/process_payment_job.rb
class ProcessPaymentJob < ApplicationJob
  queue_as :payments
  retry_on Rma::Payment::Gateway::NetworkError, wait: :exponentially_longer, attempts: 5
  discard_on Rma::Payment::Gateway::InvalidParameterError
  
  def perform(payment_id, step, params = {})
    payment = Payment.find(payment_id)
    processor = PaymentProcessor.new(payment)
    
    case step
    when 'authorize'
      processor.authorize
    when 'verify_account'
      processor.verify_account(params[:bank_id], params[:account_number])
    when 'complete'
      processor.complete(params[:otp])
    end
  rescue Rma::Payment::Gateway::Error => e
    payment.update(status: 'failed', error_message: e.message)
    raise
  end
end
```

### Webhook Handler

```ruby
# app/controllers/webhooks/rma_controller.rb
module Webhooks
  class RmaController < ApplicationController
    skip_before_action :verify_authenticity_token
    
    def payment_status
      # Handle payment status webhook from RMA
      transaction_id = params[:transaction_id]
      status = params[:status]
      
      payment = Payment.find_by(transaction_id: transaction_id)
      
      if payment
        payment.update_from_webhook(status, params)
        head :ok
      else
        head :not_found
      end
    end
  end
end
```

### Payment Analytics

```ruby
# app/services/payment_analytics.rb
class PaymentAnalytics
  def self.success_rate(period: 30.days)
    total = Payment.where('created_at > ?', period.ago).count
    successful = Payment.completed.where('created_at > ?', period.ago).count
    
    return 0 if total.zero?
    (successful.to_f / total * 100).round(2)
  end
  
  def self.average_completion_time
    Payment.completed.average('EXTRACT(EPOCH FROM (completed_at - created_at))')
  end
  
  def self.failure_reasons
    Payment.failed.group(:error_message).count
  end
end
```

For more examples, see the [Usage Guide](USAGE_GUIDE.md).

