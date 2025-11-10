#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/flash'
require 'rma/payment/gateway'

# Configure RMA Payment Gateway
configure do
  Rma::Payment::Gateway.configure do |config|
    config.base_url = ENV['RMA_BASE_URL']
    config.rsa_key_path = File.join(settings.root, 'config', 'rma_private_key.pem')
    config.beneficiary_id = ENV['RMA_BENEFICIARY_ID']
    config.payment_description = ENV['RMA_PAYMENT_DESCRIPTION']
  end
  
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET'] || 'your-secret-key'
end

helpers do
  def rma_client
    @rma_client ||= Rma::Payment::Gateway::Client.new
  end
  
  def format_amount(amount)
    "%.2f" % amount
  end
end

# Home page
get '/' do
  erb :index
end

# Payment form
get '/payment/new' do
  erb :payment_form
end

# Process payment authorization
post '/payment/authorize' do
  begin
    response = rma_client.authorization.call(
      params[:order_no],
      params[:amount].to_f,
      params[:email]
    )
    
    session[:transaction_id] = response["bfs_bfsTxnId"]
    session[:order_no] = params[:order_no]
    session[:amount] = params[:amount]
    session[:email] = params[:email]
    
    flash[:success] = "Payment authorized successfully!"
    redirect '/payment/account-verification'
    
  rescue Rma::Payment::Gateway::Error => e
    flash[:error] = "Authorization failed: #{e.message}"
    redirect '/payment/new'
  end
end

# Account verification form
get '/payment/account-verification' do
  redirect '/payment/new' unless session[:transaction_id]
  erb :account_verification
end

# Process account verification
post '/payment/verify-account' do
  begin
    response = rma_client.account_inquiry.call(
      session[:transaction_id],
      params[:bank_id],
      params[:account_no]
    )
    
    session[:account_name] = response["bfs_remitterName"]
    session[:bank_id] = params[:bank_id]
    session[:account_no] = params[:account_no]
    
    flash[:success] = "Account verified! OTP sent to your registered mobile."
    redirect '/payment/otp-verification'
    
  rescue Rma::Payment::Gateway::Error => e
    flash[:error] = "Account verification failed: #{e.message}"
    redirect '/payment/account-verification'
  end
end

# OTP verification form
get '/payment/otp-verification' do
  redirect '/payment/new' unless session[:transaction_id]
  erb :otp_verification
end

# Complete payment
post '/payment/complete' do
  begin
    response = rma_client.debit_request.call(
      session[:transaction_id],
      params[:otp]
    )
    
    # Store payment details for success page
    session[:payment_completed] = true
    session[:final_response] = response
    
    redirect '/payment/success'
    
  rescue Rma::Payment::Gateway::Error => e
    flash[:error] = "Payment failed: #{e.message}"
    redirect '/payment/otp-verification'
  end
end

# Payment success page
get '/payment/success' do
  redirect '/payment/new' unless session[:payment_completed]
  erb :success
end

# Clear session and start over
get '/payment/reset' do
  session.clear
  redirect '/'
end

__END__

@@layout
<!DOCTYPE html>
<html>
<head>
  <title>RMA Payment Gateway Demo</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    .container { max-width: 600px; margin: 0 auto; }
    .form-group { margin-bottom: 15px; }
    label { display: block; margin-bottom: 5px; font-weight: bold; }
    input, select { width: 100%; padding: 8px; border: 1px solid #ddd; }
    button { background: #007cba; color: white; padding: 10px 20px; border: none; cursor: pointer; }
    .alert { padding: 10px; margin: 10px 0; border-radius: 4px; }
    .alert-success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
    .alert-error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
  </style>
</head>
<body>
  <div class="container">
    <h1>RMA Payment Gateway Demo</h1>
    
    <% if flash[:success] %>
      <div class="alert alert-success"><%= flash[:success] %></div>
    <% end %>
    
    <% if flash[:error] %>
      <div class="alert alert-error"><%= flash[:error] %></div>
    <% end %>
    
    <%= yield %>
  </div>
</body>
</html>

@@index
<h2>Welcome to RMA Payment Gateway Demo</h2>
<p>This demo shows how to integrate the RMA Payment Gateway into a Sinatra application.</p>
<a href="/payment/new">Start New Payment</a>

@@payment_form
<h2>Payment Authorization</h2>
<form method="post" action="/payment/authorize">
  <div class="form-group">
    <label>Order Number:</label>
    <input type="text" name="order_no" value="ORDER<%= Time.now.to_i %>" required>
  </div>
  
  <div class="form-group">
    <label>Amount (BTN):</label>
    <input type="number" name="amount" step="0.01" min="0.01" value="100.50" required>
  </div>
  
  <div class="form-group">
    <label>Email:</label>
    <input type="email" name="email" value="customer@example.com" required>
  </div>
  
  <button type="submit">Authorize Payment</button>
</form>

@@account_verification
<h2>Account Verification</h2>
<p><strong>Transaction ID:</strong> <%= session[:transaction_id] %></p>
<p><strong>Amount:</strong> <%= format_amount(session[:amount].to_f) %> BTN</p>

<form method="post" action="/payment/verify-account">
  <div class="form-group">
    <label>Bank:</label>
    <select name="bank_id" required>
      <option value="">Select Bank</option>
      <option value="1010">Bank of Bhutan (BOBL)</option>
      <option value="1020">Bhutan National Bank (BNBL)</option>
      <option value="1030">Druk PNB Bank Limited (DPNBL)</option>
      <option value="1040">Tashi Bank (TBank)</option>
      <option value="1050">Bhutan Development Bank Limited (BDBL)</option>
      <option value="1060">Digital Kidu (DK Bank)</option>
    </select>
  </div>
  
  <div class="form-group">
    <label>Account Number:</label>
    <input type="text" name="account_no" placeholder="Enter your account number" required>
  </div>
  
  <button type="submit">Verify Account</button>
</form>

@@otp_verification
<h2>OTP Verification</h2>
<p><strong>Account Holder:</strong> <%= session[:account_name] %></p>
<p><strong>Amount:</strong> <%= format_amount(session[:amount].to_f) %> BTN</p>
<p>Please enter the OTP sent to your registered mobile number.</p>

<form method="post" action="/payment/complete">
  <div class="form-group">
    <label>OTP:</label>
    <input type="text" name="otp" placeholder="Enter 6-digit OTP" maxlength="6" required>
  </div>
  
  <button type="submit">Complete Payment</button>
</form>

@@success
<h2>Payment Successful! 🎉</h2>
<p><strong>Transaction ID:</strong> <%= session[:final_response]['bfs_bfsTxnId'] %></p>
<p><strong>Order Number:</strong> <%= session[:final_response]['bfs_orderNo'] %></p>
<p><strong>Amount:</strong> <%= session[:final_response]['bfs_txnAmount'] %> BTN</p>
<p><strong>Status:</strong> <%= session[:final_response]['bfs_responseDesc'] %></p>

<a href="/payment/reset">Start New Payment</a>