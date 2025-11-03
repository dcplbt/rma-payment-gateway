# RMA Payment Gateway Documentation

Welcome to the RMA Payment Gateway Ruby gem documentation. This directory contains comprehensive guides and references to help you integrate the RMA Payment Gateway into your Ruby application.

## Documentation Overview

### 📚 Getting Started

- **[Main README](../README.md)** - Start here! Installation, configuration, and basic usage
- **[Quick Reference](QUICK_REFERENCE.md)** - Cheat sheet for common tasks and API methods

### 📖 Guides

- **[Usage Guide](USAGE_GUIDE.md)** - Detailed integration examples for Rails and Sinatra
- **[API Documentation](API.md)** - Complete API reference with request/response formats
- **[Code Examples](EXAMPLES.md)** - Practical code examples for common scenarios
- **[Security Guide](SECURITY.md)** - Security best practices and compliance guidelines

### 📋 Reference

- **[CHANGELOG](../CHANGELOG.md)** - Version history and release notes
- **[Code of Conduct](../CODE_OF_CONDUCT.md)** - Community guidelines

## Quick Links

### For New Users

1. Read the [Main README](../README.md) for installation and setup
2. Check the [Quick Reference](QUICK_REFERENCE.md) for common tasks
3. Review [Code Examples](EXAMPLES.md) for your use case
4. Read the [Security Guide](SECURITY.md) before going to production

### For Developers

1. [Usage Guide](USAGE_GUIDE.md) - Integration patterns
2. [API Documentation](API.md) - API details
3. [Code Examples](EXAMPLES.md) - Implementation examples
4. [CHANGELOG](../CHANGELOG.md) - What's new

### For Security Teams

1. [Security Guide](SECURITY.md) - Security best practices
2. [API Documentation](API.md) - API security details
3. [Main README](../README.md) - Configuration security

## Payment Flow Overview

The RMA Payment Gateway uses a three-step payment flow:

```
┌─────────────────────┐
│  1. Authorization   │  Merchant initiates payment
│  (AR Message)       │  Returns: Transaction ID
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  2. Account Inquiry │  Customer provides bank details
│  (AE Message)       │  Returns: Account info, sends OTP
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  3. Debit Request   │  Customer provides OTP
│  (DR Message)       │  Returns: Payment confirmation
└─────────────────────┘
```

## Key Features

- ✅ **Simple API** - Three methods for complete payment flow
- ✅ **Error Handling** - Comprehensive exception classes
- ✅ **Validation** - Built-in input validation
- ✅ **Security** - RSA authentication and HTTPS
- ✅ **Utilities** - Helper methods for common tasks
- ✅ **Well Documented** - Extensive guides and examples

## Common Use Cases

### E-commerce Checkout
See: [Usage Guide - E-commerce Checkout](USAGE_GUIDE.md#1-e-commerce-checkout)

### Subscription Payments
See: [Usage Guide - Subscription Payments](USAGE_GUIDE.md#2-subscription-payments)

### Rails Integration
See: [Usage Guide - Rails Integration](USAGE_GUIDE.md#rails-integration)

### Sinatra Integration
See: [Usage Guide - Sinatra Integration](USAGE_GUIDE.md#sinatra-integration)

## API Quick Reference

### Initialize Client

```ruby
client = Rma::Payment::Gateway::Client.new
```

### Payment Authorization

```ruby
response = client.authorization.call(order_no, amount, email)
transaction_id = response["bfs_bfsTxnId"]
```

### Account Inquiry

```ruby
response = client.account_inquiry.call(transaction_id, bank_id, account_no)
```

### Debit Request

```ruby
response = client.debit_request.call(transaction_id, otp)
```

For complete API details, see [API Documentation](API.md).

## Supported Banks

| Code | Bank Name |
|------|-----------|
| 1010 | Bank of Bhutan (BOBL) |
| 1020 | Bhutan National Bank (BNBL) |
| 1030 | Druk PNB Bank Limited (DPNBL) |
| 1040 | Tashi Bank (TBank) |
| 1050 | Bhutan Development Bank Limited (BDBL) |
| 1060 | Digital Kidu (DK Bank) |

## Error Handling

The gem provides specific exception classes:

- `ConfigurationError` - Configuration issues
- `InvalidParameterError` - Invalid input parameters
- `AuthenticationError` - Authentication failures
- `NetworkError` - Network connectivity issues
- `APIError` - API-level errors
- `SignatureError` - Signature validation errors
- `TransactionError` - Transaction-specific errors

See [Code Examples - Error Handling](EXAMPLES.md#error-handling-examples) for usage.

## Security Best Practices

1. **Never commit RSA private keys** to version control
2. **Use environment variables** for sensitive configuration
3. **Validate all inputs** before sending to API
4. **Mask sensitive data** in logs
5. **Use HTTPS** for all communications
6. **Implement rate limiting** to prevent abuse
7. **Store transaction IDs** securely

For complete security guidelines, see [Security Guide](SECURITY.md).

## Testing

The gem includes comprehensive test coverage. For testing your integration:

```ruby
# RSpec example
RSpec.describe PaymentService do
  let(:client) { instance_double(Rma::Payment::Gateway::Client) }
  
  before do
    allow(Rma::Payment::Gateway::Client).to receive(:new).and_return(client)
  end
  
  # Your tests here
end
```

See [Code Examples - Testing](EXAMPLES.md#testing-examples) for more examples.

## Troubleshooting

### Common Issues

1. **Configuration Error**
   - Check environment variables
   - Verify RSA key path
   - See: [Usage Guide - Troubleshooting](USAGE_GUIDE.md#troubleshooting)

2. **Network Timeout**
   - Increase timeout settings
   - Check network connectivity
   - See: [API Documentation - Best Practices](API.md#best-practices)

3. **Invalid OTP**
   - Verify OTP is correct
   - Check if OTP expired
   - Restart payment flow if needed

4. **Transaction Not Found**
   - Verify transaction ID
   - Check if transaction expired
   - Ensure consistent transaction ID across steps

## Contributing

We welcome contributions! Please see:

- [Main README - Contributing](../README.md#contributing)
- [Code of Conduct](../CODE_OF_CONDUCT.md)

## Support

### Documentation Issues

If you find issues with the documentation:
- Open an issue: https://github.com/dcplbt/rma-payment-gateway/issues
- Submit a PR with improvements

### Integration Help

For help with integration:
- Check the [Usage Guide](USAGE_GUIDE.md)
- Review [Code Examples](EXAMPLES.md)
- Open an issue on GitHub

### Security Concerns

For security-related issues:
- Email: tashii.dendupp@gmail.com
- Use GitHub Security Advisories for vulnerabilities

## Version Information

Current Version: **1.0.0**

See [CHANGELOG](../CHANGELOG.md) for version history.

## License

This gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

## Document Index

| Document | Description | Audience |
|----------|-------------|----------|
| [Main README](../README.md) | Installation, configuration, basic usage | Everyone |
| [Quick Reference](QUICK_REFERENCE.md) | Cheat sheet and quick lookup | Developers |
| [Usage Guide](USAGE_GUIDE.md) | Integration examples and patterns | Developers |
| [API Documentation](API.md) | Complete API reference | Developers |
| [Code Examples](EXAMPLES.md) | Practical code examples | Developers |
| [Security Guide](SECURITY.md) | Security best practices | Security Teams, DevOps |
| [CHANGELOG](../CHANGELOG.md) | Version history | Everyone |
| [Code of Conduct](../CODE_OF_CONDUCT.md) | Community guidelines | Contributors |

---

**Last Updated:** 2025-11-03  
**Gem Version:** 1.0.0  
**Maintained By:** Tashi Dendup (tashii.dendupp@gmail.com)

