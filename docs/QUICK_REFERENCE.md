# Quick Reference Guide

A quick reference for the RMA Payment Gateway Ruby gem.

## Installation

```bash
gem install rma-payment-gateway
# or add to Gemfile
gem 'rma-payment-gateway'
```

## Configuration

### Environment Variables

```env
RMA_BASE_URL=https://your-rma-gateway-url.com
RMA_RSA_KEY_PATH=/path/to/rsa_private_key.pem
RMA_BENEFICIARY_ID=your_beneficiary_id
RMA_PAYMENT_DESCRIPTION=Payment for services
```

### Code Configuration

```ruby
Rma::Payment::Gateway.configure do |config|
  config.base_url = 'https://your-rma-gateway-url.com'
  config.rsa_key_path = '/path/to/rsa_private_key.pem'
  config.beneficiary_id = 'your_beneficiary_id'
  config.payment_description = 'Payment for services'
  config.timeout = 30
  config.open_timeout = 10
end
```

## Payment Flow

```
1. Authorization → 2. Account Inquiry → 3. Debit Request
```

## Basic Usage

```ruby
require 'rma/payment/gateway'

client = Rma::Payment::Gateway::Client.new

# Step 1: Authorization
response = client.authorization.call("ORDER123", 100.50, "customer@email.com")
transaction_id = response["bfs_bfsTxnId"]

# Step 2: Account Inquiry
response = client.account_inquiry.call(transaction_id, "1010", "12345678")

# Step 3: Debit Request
response = client.debit_request.call(transaction_id, "123456")
```

## API Methods

### Authorization

```ruby
client.authorization.call(order_no, amount, email)
```

**Parameters:**
- `order_no` (String) - Unique order number
- `amount` (Numeric) - Payment amount
- `email` (String) - Customer email

**Returns:** Hash with transaction details

### Account Inquiry

```ruby
client.account_inquiry.call(transaction_id, bank_id, account_no)
```

**Parameters:**
- `transaction_id` (String) - Transaction ID from authorization
- `bank_id` (String) - Bank code (1010-1060)
- `account_no` (String) - Customer account number

**Returns:** Hash with account details

### Debit Request

```ruby
client.debit_request.call(transaction_id, otp)
```

**Parameters:**
- `transaction_id` (String) - Transaction ID from authorization
- `otp` (String) - OTP received by customer

**Returns:** Hash with payment confirmation

## Bank Codes

| Code | Bank Name |
|------|-----------|
| 1010 | Bank of Bhutan (BOBL) |
| 1020 | Bhutan National Bank (BNBL) |
| 1030 | Druk PNB Bank Limited (DPNBL) |
| 1040 | Tashi Bank (TBank) |
| 1050 | Bhutan Development Bank Limited (BDBL) |
| 1060 | Digital Kidu (DK Bank) |

## Response Codes

| Code | Description |
|------|-------------|
| 00 | Success |
| 01 | Invalid request |
| 02 | Invalid beneficiary |
| 03 | Invalid transaction |
| 04 | Insufficient funds |
| 05 | Invalid OTP |
| 06 | OTP expired |
| 99 | System error |

## Error Handling

```ruby
begin
  client.authorization.call(order_no, amount, email)
rescue Rma::Payment::Gateway::ConfigurationError => e
  # Configuration issue
rescue Rma::Payment::Gateway::InvalidParameterError => e
  # Invalid input
rescue Rma::Payment::Gateway::AuthenticationError => e
  # Authentication failed
rescue Rma::Payment::Gateway::NetworkError => e
  # Network issue
rescue Rma::Payment::Gateway::APIError => e
  # API error
rescue Rma::Payment::Gateway::Error => e
  # Generic error
end
```

## Exception Classes

```
Rma::Payment::Gateway::Error (base)
├── ConfigurationError
├── AuthenticationError
├── InvalidParameterError
├── NetworkError
├── SignatureError
└── APIError
    └── TransactionError
```

## Utility Methods

### Validation

```ruby
# Email
Rma::Payment::Gateway::Utils.valid_email?("user@example.com")

# Amount
Rma::Payment::Gateway::Utils.valid_amount?(100.50)

# Bank code
Rma::Payment::Gateway::Utils.valid_bank_code?("1010")

# Account number
Rma::Payment::Gateway::Utils.valid_account_number?("12345678")

# Phone number
Rma::Payment::Gateway::Utils.valid_phone_number?("17123456")
```

### Formatting

```ruby
# Format amount
Rma::Payment::Gateway::Utils.format_amount(100.5)
# => "100.50"

# Generate timestamp
Rma::Payment::Gateway::Utils.generate_timestamp
# => "20231215143022"

# Mask sensitive data
Rma::Payment::Gateway::Utils.mask_sensitive("1234567890", 2)
# => "12******90"

# Get bank name
Rma::Payment::Gateway::Utils.bank_name("1010")
# => "Bank of Bhutan (BOBL)"
```

## Common Patterns

### With Error Handling

```ruby
def process_payment(order_no, amount, email, bank_id, account_no, otp)
  client = Rma::Payment::Gateway::Client.new
  
  # Step 1
  auth = client.authorization.call(order_no, amount, email)
  txn_id = auth["bfs_bfsTxnId"]
  
  # Step 2
  client.account_inquiry.call(txn_id, bank_id, account_no)
  
  # Step 3
  client.debit_request.call(txn_id, otp)
rescue Rma::Payment::Gateway::Error => e
  Rails.logger.error("Payment failed: #{e.message}")
  raise
end
```

### With Retry Logic

```ruby
def authorize_with_retry(order_no, amount, email, retries: 3)
  client = Rma::Payment::Gateway::Client.new
  attempt = 0
  
  begin
    client.authorization.call(order_no, amount, email)
  rescue Rma::Payment::Gateway::NetworkError => e
    attempt += 1
    retry if attempt < retries
    raise
  end
end
```

### Rails Service Object

```ruby
class PaymentService
  def initialize(order)
    @order = order
    @client = Rma::Payment::Gateway::Client.new
  end
  
  def authorize
    response = @client.authorization.call(
      @order.number,
      @order.total,
      @order.customer_email
    )
    @order.update!(transaction_id: response["bfs_bfsTxnId"])
  end
end
```

## Testing

### RSpec Mock

```ruby
let(:client) { instance_double(Rma::Payment::Gateway::Client) }

before do
  allow(Rma::Payment::Gateway::Client).to receive(:new).and_return(client)
  allow(client).to receive_message_chain(:authorization, :call).and_return({
    "bfs_bfsTxnId" => "TXN123",
    "bfs_responseCode" => "00"
  })
end
```

## Security Checklist

- [ ] RSA key stored securely (not in repo)
- [ ] Environment variables configured
- [ ] HTTPS enforced
- [ ] Input validation enabled
- [ ] Sensitive data masked in logs
- [ ] Error messages don't leak info
- [ ] Rate limiting implemented
- [ ] Audit logging enabled

## Common Issues

### Configuration Error

```ruby
# Check configuration
config = Rma::Payment::Gateway.configuration
puts config.missing_fields
```

### Network Timeout

```ruby
# Increase timeout
config.timeout = 60
config.open_timeout = 20
```

### Invalid OTP

- Verify OTP is correct
- Check if OTP expired
- Restart payment flow if needed

## Links

- [Full Documentation](../README.md)
- [API Reference](API.md)
- [Usage Guide](USAGE_GUIDE.md)
- [Security Guide](SECURITY.md)
- [Code Examples](EXAMPLES.md)
- [GitHub Repository](https://github.com/dcplbt/rma-payment-gateway)

## Support

- GitHub Issues: https://github.com/dcplbt/rma-payment-gateway/issues
- Email: tashii.dendupp@gmail.com

