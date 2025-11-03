# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-11-03

### Added

- Initial release of RMA Payment Gateway Ruby gem
- Payment Authorization functionality (AR message type)
- Account Inquiry functionality (AE message type)
- Debit Request functionality (DR message type)
- Comprehensive error handling with custom exception classes
  - `ConfigurationError` for configuration issues
  - `AuthenticationError` for authentication failures
  - `InvalidParameterError` for validation errors
  - `NetworkError` for network-related issues
  - `APIError` for API-level errors
  - `SignatureError` for signature validation
  - `TransactionError` for transaction-specific errors
- Utility methods for validation and formatting
  - Email validation
  - Amount validation and formatting
  - Bank code validation
  - Account number validation
  - Phone number validation (Bhutan format)
  - Timestamp generation
  - Sensitive data masking
- Configuration management via environment variables
- Support for all major banks in Bhutan (BOBL, BNBL, DPNBL, TBank, BDBL, DK Bank)
- Comprehensive documentation
  - README with installation and usage instructions
  - API documentation
  - Usage guide with Rails and Sinatra examples
  - Security guide
  - Code examples
- RSpec test suite
- RuboCop linting configuration
- GitHub Actions CI/CD pipeline

### Security

- RSA key-based authentication
- HTTPS-only communication
- Input validation for all parameters
- Sensitive data masking in logs

### Documentation

- Complete README with examples
- API reference documentation
- Security best practices guide
- Usage guide for Rails and Sinatra
- Comprehensive code examples
- Inline code documentation
