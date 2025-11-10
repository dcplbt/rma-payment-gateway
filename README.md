# RMA Payment Gateway Ruby Gem

[![Gem Version](https://badge.fury.io/rb/rma-payment-gateway.svg)](https://badge.fury.io/rb/rma-payment-gateway)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%202.7.0-ruby.svg)](https://www.ruby-lang.org/en/)

A Ruby gem for integrating with the RMA (Royal Monetary Authority of Bhutan) Payment Gateway API. This gem provides a simple and intuitive interface for processing payments through the RMA Payment Gateway system.

## Features

- 🔐 **Payment Authorization** - Initiate payment requests with order details
- 🏦 **Account Inquiry** - Verify customer bank account information
- 💳 **Debit Request** - Complete payment transactions with OTP confirmation
- ✅ **Input Validation** - Built-in validation for amounts, emails, and account numbers
- 🛡️ **Error Handling** - Comprehensive error handling with custom exceptions
- 🔧 **Configurable** - Easy configuration via environment variables or code
- 📝 **Well Documented** - Extensive documentation and examples

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Payment Flow](#payment-flow)
  - [Step 1: Payment Authorization](#step-1-payment-authorization)
  - [Step 2: Account Inquiry](#step-2-account-inquiry)
  - [Step 3: Debit Request](#step-3-debit-request)
- [Error Handling](#error-handling)
- [Utilities](#utilities)
- [Development](#development)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rma-payment-gateway'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install rma-payment-gateway
```

## Configuration

### Environment Variables

Create a `.env` file in your project root with the following variables:

```env
RMA_BASE_URL=https://your-rma-gateway-url.com
RMA_RSA_KEY_PATH=/path/to/your/rsa_private_key.pem
RMA_BENEFICIARY_ID=your_beneficiary_id
RMA_PAYMENT_DESCRIPTION=Payment for services
```

### Configuration Block

Alternatively, configure the gem in your application:

```ruby
require 'rma/payment/gateway'

Rma::Payment::Gateway.configure do |config|
  config.base_url = 'https://your-rma-gateway-url.com'
  config.rsa_key_path = '/path/to/your/rsa_private_key.pem'
  config.beneficiary_id = 'your_beneficiary_id'
  config.payment_description = 'Payment for services'
  config.timeout = 30  # Optional: default is 30 seconds
  config.open_timeout = 10  # Optional: default is 10 seconds
end
```

### Configuration Options

| Option                | Required | Description                      | Default |
| --------------------- | -------- | -------------------------------- | ------- |
| `base_url`            | Yes      | RMA Payment Gateway API base URL | -       |
| `rsa_key_path`        | Yes      | Path to RSA private key file     | -       |
| `beneficiary_id`      | Yes      | Your merchant/beneficiary ID     | -       |
| `payment_description` | Yes      | Default payment description      | -       |
| `timeout`             | No       | Request timeout in seconds       | 30      |
| `open_timeout`        | No       | Connection timeout in seconds    | 10      |

## Usage

### Payment Flow

The RMA Payment Gateway follows a three-step payment flow:

```
1. Payment Authorization → 2. Account Inquiry → 3. Debit Request
```

1. **Payment Authorization**: Initiate a payment request with order details
2. **Account Inquiry**: Customer provides bank details and receives OTP
3. **Debit Request**: Complete payment by submitting the OTP

### Step 1: Payment Authorization

Initiate a payment request:

```ruby
require 'rma/payment/gateway'

# Initialize the client
client = Rma::Payment::Gateway::Client.new

# Request payment authorization
begin
  response = client.authorization.call(
    "ORDER123",           # order_no: Unique order number
    100.50,              # amount: Payment amount
    "customer@email.com" # email: Customer email
  )

  # Extract transaction ID for next steps
  transaction_id = response["bfs_bfsTxnId"]

  puts "Authorization successful!"
  puts "Transaction ID: #{transaction_id}"
  puts "Response: #{response}"
rescue Rma::Payment::Gateway::AuthenticationError => e
  puts "Authorization failed: #{e.message}"
rescue Rma::Payment::Gateway::InvalidParameterError => e
  puts "Invalid parameters: #{e.message}"
end
```

**Response Example:**

```ruby
{
  "bfs_bfsTxnId" => "TXN123456789",
  "bfs_responseCode" => "00",
  "bfs_responseDesc" => "Success",
  "bfs_orderNo" => "ORDER123",
  "bfs_txnAmount" => "100.50"
}
```

### Step 2: Account Inquiry

Verify customer's bank account and trigger OTP:

```ruby
# Customer provides their bank details
transaction_id = "TXN123456789"  # From authorization step
bank_id = "1010"                 # Bank code (see supported banks below)
account_no = "12345678"          # Customer's account number

begin
  response = client.account_inquiry.call(
    transaction_id,
    bank_id,
    account_no
  )

  puts "Account inquiry successful!"
  puts "OTP sent to customer's registered mobile"
  puts "Account Name: #{response["bfs_remitterName"]}"
rescue Rma::Payment::Gateway::AuthenticationError => e
  puts "Account inquiry failed: #{e.message}"
end
```

**Supported Banks:**

| Bank Code | Bank Name                              |
| --------- | -------------------------------------- |
| 1010      | Bank of Bhutan (BOBL)                  |
| 1020      | Bhutan National Bank (BNBL)            |
| 1030      | Druk PNB Bank Limited (DPNBL)          |
| 1040      | Tashi Bank (TBank)                     |
| 1050      | Bhutan Development Bank Limited (BDBL) |
| 1060      | Digital Kidu (DK Bank)                 |

**Response Example:**

```ruby
{
  "bfs_bfsTxnId" => "TXN123456789",
  "bfs_responseCode" => "00",
  "bfs_responseDesc" => "Success",
  "bfs_remitterName" => "John Doe",
  "bfs_remitterAccNo" => "12345678"
}
```

### Step 3: Debit Request

Complete the payment with OTP:

```ruby
# Customer provides the OTP received on their mobile
transaction_id = "TXN123456789"  # From authorization step
otp = "123456"                   # OTP from customer

begin
  response = client.debit_request.call(
    transaction_id,
    otp
  )

  puts "Payment successful!"
  puts "Transaction completed"
  puts "Response: #{response}"
rescue Rma::Payment::Gateway::AuthenticationError => e
  puts "Payment failed: #{e.message}"
end
```

**Response Example:**

```ruby
{
  "bfs_bfsTxnId" => "TXN123456789",
  "bfs_responseCode" => "00",
  "bfs_responseDesc" => "Transaction Successful",
  "bfs_txnAmount" => "100.50",
  "bfs_orderNo" => "ORDER123"
}
```

### Complete Payment Flow Example

```ruby
require 'rma/payment/gateway'

# Initialize client
client = Rma::Payment::Gateway::Client.new

# Step 1: Authorization
puts "Step 1: Initiating payment authorization..."
auth_response = client.authorization.call("ORDER123", 100.50, "customer@email.com")
transaction_id = auth_response["bfs_bfsTxnId"]
puts "✓ Authorization successful. Transaction ID: #{transaction_id}"

# Step 2: Account Inquiry
puts "\nStep 2: Verifying account and sending OTP..."
# In a real application, you would collect these from the customer
bank_id = "1010"
account_no = "12345678"

inquiry_response = client.account_inquiry.call(transaction_id, bank_id, account_no)
puts "✓ Account verified. OTP sent to customer."
puts "  Account holder: #{inquiry_response["bfs_remitterName"]}"

# Step 3: Debit Request
puts "\nStep 3: Completing payment with OTP..."
# In a real application, you would collect the OTP from the customer
otp = "123456"

debit_response = client.debit_request.call(transaction_id, otp)
puts "✓ Payment completed successfully!"
puts "  Amount: #{debit_response["bfs_txnAmount"]} BTN"
```

## Error Handling

The gem provides specific exception classes for different error scenarios:

```ruby
begin
  client.authorization.call(order_no, amount, email)
rescue Rma::Payment::Gateway::ConfigurationError => e
  # Missing or invalid configuration
  puts "Configuration error: #{e.message}"
rescue Rma::Payment::Gateway::InvalidParameterError => e
  # Invalid input parameters
  puts "Invalid parameters: #{e.message}"
  puts "Response code: #{e.response_code}"
rescue Rma::Payment::Gateway::AuthenticationError => e
  # Authentication or authorization failed
  puts "Authentication error: #{e.message}"
rescue Rma::Payment::Gateway::NetworkError => e
  # Network connectivity issues
  puts "Network error: #{e.message}"
rescue Rma::Payment::Gateway::APIError => e
  # API-level errors
  puts "API error: #{e.message}"
  puts "Response code: #{e.response_code}"
rescue Rma::Payment::Gateway::Error => e
  # Generic gateway error
  puts "Gateway error: #{e.message}"
end
```

### Exception Hierarchy

```
Rma::Payment::Gateway::Error (base class)
├── ConfigurationError
├── AuthenticationError
├── InvalidParameterError
├── NetworkError
├── SignatureError
└── APIError
    └── TransactionError
```

## Utilities

The gem includes utility methods for validation and formatting:

### Validation Methods

```ruby
# Email validation
Rma::Payment::Gateway::Utils.valid_email?("user@example.com")
# => true

# Amount validation
Rma::Payment::Gateway::Utils.valid_amount?(100.50)
# => true

# Bank code validation
Rma::Payment::Gateway::Utils.valid_bank_code?("1010")
# => true

# Account number validation (8-15 digits)
Rma::Payment::Gateway::Utils.valid_account_number?("12345678")
# => true

# Phone number validation (Bhutan format - 8 digits)
Rma::Payment::Gateway::Utils.valid_phone_number?("17123456")
# => true
```

### Formatting Methods

```ruby
# Format amount to 2 decimal places
Rma::Payment::Gateway::Utils.format_amount(100.5)
# => "100.50"

# Generate timestamp
Rma::Payment::Gateway::Utils.generate_timestamp
# => "20231215143022"

# Mask sensitive data
Rma::Payment::Gateway::Utils.mask_sensitive("1234567890", 2)
# => "12******90"

# Get bank name from code
Rma::Payment::Gateway::Utils.bank_name("1010")
# => "Bank of Bhutan (BOBL)"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

```bash
# Install dependencies
bin/setup

# Run tests
bundle exec rake spec

# Run RuboCop
bundle exec rubocop

# Interactive console
bin/console
```

## Testing

The gem uses RSpec for testing. Run the test suite:

```bash
bundle exec rspec
```

Run with coverage:

```bash
COVERAGE=true bundle exec rspec
```

## API Response Codes

Common response codes from the RMA Payment Gateway:

| Code | Description         |
| ---- | ------------------- |
| 00   | Success             |
| 01   | Invalid request     |
| 02   | Invalid beneficiary |
| 03   | Invalid transaction |
| 04   | Insufficient funds  |
| 05   | Invalid OTP         |
| 06   | OTP expired         |
| 99   | System error        |

## Security Considerations

1. **Never commit your RSA private key** to version control
2. **Use environment variables** for sensitive configuration
3. **Validate all user inputs** before sending to the API
4. **Log transactions** but mask sensitive data
5. **Use HTTPS** for all API communications
6. **Implement rate limiting** to prevent abuse
7. **Store transaction IDs** securely for reconciliation

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dcplbt/rma-payment-gateway. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/dcplbt/rma-payment-gateway/blob/main/CODE_OF_CONDUCT.md).

### How to Contribute

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the RMA Payment Gateway project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/dcplbt/rma-payment-gateway/blob/main/CODE_OF_CONDUCT.md).

## Support

For issues, questions, or contributions, please visit:

- GitHub Issues: https://github.com/dcplbt/rma-payment-gateway/issues
- Email: tashii.dendupp@gmail.com

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes.
