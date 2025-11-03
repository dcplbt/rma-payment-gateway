# Security Guide

This document outlines security best practices for integrating the RMA Payment Gateway into your application.

## Table of Contents

- [Overview](#overview)
- [Configuration Security](#configuration-security)
- [Data Protection](#data-protection)
- [Network Security](#network-security)
- [Application Security](#application-security)
- [Compliance](#compliance)
- [Incident Response](#incident-response)

## Overview

Payment processing requires strict security measures to protect sensitive customer data and prevent fraud. This guide covers essential security practices for the RMA Payment Gateway integration.

## Configuration Security

### 1. RSA Private Key Management

**DO:**
- ✅ Store RSA private keys outside the application directory
- ✅ Use file permissions to restrict access (chmod 600)
- ✅ Use environment variables for key paths
- ✅ Rotate keys periodically
- ✅ Keep backup keys in secure storage

**DON'T:**
- ❌ Commit private keys to version control
- ❌ Store keys in the application directory
- ❌ Share keys via email or chat
- ❌ Use the same key across environments

**Example:**

```bash
# Set proper permissions
chmod 600 /secure/path/rma_private_key.pem
chown app_user:app_group /secure/path/rma_private_key.pem

# Verify permissions
ls -la /secure/path/rma_private_key.pem
# Should show: -rw------- 1 app_user app_group
```

### 2. Environment Variables

**DO:**
- ✅ Use `.env` files for local development
- ✅ Use secure secret management in production (e.g., AWS Secrets Manager, HashiCorp Vault)
- ✅ Add `.env` to `.gitignore`
- ✅ Use different credentials for each environment

**Example `.gitignore`:**

```
.env
.env.local
.env.*.local
config/rma_private_key.pem
*.pem
```

**Example Production Setup (Rails):**

```ruby
# config/initializers/rma_payment_gateway.rb
Rma::Payment::Gateway.configure do |config|
  # Use Rails credentials or environment variables
  config.base_url = Rails.application.credentials.dig(:rma, :base_url) || ENV['RMA_BASE_URL']
  config.rsa_key_path = Rails.application.credentials.dig(:rma, :key_path) || ENV['RMA_RSA_KEY_PATH']
  config.beneficiary_id = Rails.application.credentials.dig(:rma, :beneficiary_id) || ENV['RMA_BENEFICIARY_ID']
  config.payment_description = ENV['RMA_PAYMENT_DESCRIPTION']
end
```

### 3. Configuration Validation

Always validate configuration on application startup:

```ruby
# config/initializers/rma_payment_gateway.rb
config = Rma::Payment::Gateway.configuration

unless config.valid?
  raise "RMA Payment Gateway configuration is invalid: #{config.missing_fields.join(', ')}"
end

# Verify RSA key file exists and is readable
unless File.exist?(config.rsa_key_path)
  raise "RMA RSA key file not found: #{config.rsa_key_path}"
end

unless File.readable?(config.rsa_key_path)
  raise "RMA RSA key file is not readable: #{config.rsa_key_path}"
end
```

## Data Protection

### 1. Sensitive Data Handling

**Never log or store:**
- OTP codes
- Full account numbers (mask if needed)
- RSA private keys
- Customer passwords

**Example - Masked Logging:**

```ruby
def log_payment_attempt(transaction_id, account_number)
  Rails.logger.info({
    event: 'payment_attempt',
    transaction_id: transaction_id,
    account_number: Rma::Payment::Gateway::Utils.mask_sensitive(account_number, 2),
    timestamp: Time.current
  }.to_json)
end
```

### 2. Database Security

**Encrypt sensitive data at rest:**

```ruby
# Using Rails encrypted attributes
class Payment < ApplicationRecord
  encrypts :customer_account_number
  encrypts :rma_transaction_id
  
  # Don't store OTP - it's single-use
end
```

### 3. Data Retention

**Implement data retention policies:**

```ruby
class Payment < ApplicationRecord
  # Delete old payment records after retention period
  scope :expired, -> { where('created_at < ?', 7.years.ago) }
  
  def self.cleanup_old_records
    expired.find_each do |payment|
      payment.anonymize! # Remove PII
      payment.destroy if payment.can_be_deleted?
    end
  end
end
```

### 4. PII Protection

**Minimize PII collection:**

```ruby
# Only collect what's necessary
def create_payment(order)
  client.authorization.call(
    order.number,
    order.total,
    order.customer_email # Only email, not full customer details
  )
end
```

## Network Security

### 1. HTTPS Only

**Always use HTTPS:**

```ruby
# Verify base URL uses HTTPS
config = Rma::Payment::Gateway.configuration

unless config.base_url.start_with?('https://')
  raise "RMA base URL must use HTTPS: #{config.base_url}"
end
```

### 2. SSL/TLS Configuration

**Use strong SSL/TLS settings:**

```ruby
# In production, verify SSL certificates
Rma::Payment::Gateway.configure do |config|
  config.base_url = ENV['RMA_BASE_URL']
  # Faraday will verify SSL by default
end
```

### 3. Network Timeouts

**Set appropriate timeouts to prevent hanging:**

```ruby
Rma::Payment::Gateway.configure do |config|
  config.timeout = 30        # Request timeout
  config.open_timeout = 10   # Connection timeout
end
```

### 4. IP Whitelisting

**Restrict API access by IP (if supported):**

```ruby
# Configure firewall rules to only allow outbound connections
# to RMA Payment Gateway IP addresses
```

## Application Security

### 1. Input Validation

**Always validate user inputs:**

```ruby
class PaymentController < ApplicationController
  def create
    # Validate before processing
    validate_payment_params!
    
    # Process payment
    process_payment
  end
  
  private
  
  def validate_payment_params!
    unless Rma::Payment::Gateway::Utils.valid_amount?(params[:amount])
      raise ActionController::BadRequest, "Invalid amount"
    end
    
    unless Rma::Payment::Gateway::Utils.valid_email?(params[:email])
      raise ActionController::BadRequest, "Invalid email"
    end
    
    unless Rma::Payment::Gateway::Utils.valid_bank_code?(params[:bank_id])
      raise ActionController::BadRequest, "Invalid bank code"
    end
  end
end
```

### 2. CSRF Protection

**Enable CSRF protection:**

```ruby
# Rails - enabled by default
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
end
```

### 3. Rate Limiting

**Implement rate limiting:**

```ruby
# Using Rack::Attack
class Rack::Attack
  # Limit payment attempts per IP
  throttle('payments/ip', limit: 5, period: 1.hour) do |req|
    req.ip if req.path.start_with?('/payments') && req.post?
  end
  
  # Limit payment attempts per user
  throttle('payments/user', limit: 10, period: 1.hour) do |req|
    req.session[:user_id] if req.path.start_with?('/payments') && req.post?
  end
end
```

### 4. Session Security

**Secure session management:**

```ruby
# Rails session configuration
Rails.application.config.session_store :cookie_store,
  key: '_app_session',
  secure: Rails.env.production?,  # HTTPS only in production
  httponly: true,                 # Not accessible via JavaScript
  same_site: :lax                 # CSRF protection
```

### 5. Authorization

**Verify user authorization:**

```ruby
class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_payment!
  
  def complete
    # User can only complete their own payments
    @payment = current_user.payments.find(params[:id])
    # Process payment
  end
  
  private
  
  def authorize_payment!
    unless current_user.can_make_payment?
      redirect_to root_path, alert: 'Not authorized'
    end
  end
end
```

### 6. Idempotency

**Prevent duplicate payments:**

```ruby
class Payment < ApplicationRecord
  validates :order_number, uniqueness: { scope: :status }
  
  def self.create_or_find_by_order(order_number)
    # Atomic operation to prevent race conditions
    transaction do
      find_or_create_by!(order_number: order_number) do |payment|
        payment.status = 'pending'
      end
    end
  end
end
```

## Compliance

### 1. PCI DSS Compliance

**Key requirements:**
- Don't store card data (RMA handles this)
- Use HTTPS for all communications
- Implement access controls
- Maintain audit logs
- Regular security testing

### 2. Data Privacy Regulations

**GDPR/Privacy compliance:**

```ruby
class Customer < ApplicationRecord
  # Right to be forgotten
  def anonymize!
    update!(
      email: "deleted_#{id}@example.com",
      name: "Deleted User",
      phone: nil
    )
  end
  
  # Data export
  def export_data
    {
      personal_info: attributes.slice('name', 'email', 'phone'),
      payments: payments.map(&:export_data)
    }
  end
end
```

### 3. Audit Logging

**Maintain comprehensive audit logs:**

```ruby
class AuditLog < ApplicationRecord
  def self.log_payment_event(event_type, user, details)
    create!(
      event_type: event_type,
      user_id: user&.id,
      ip_address: details[:ip],
      user_agent: details[:user_agent],
      details: details.to_json,
      created_at: Time.current
    )
  end
end

# Usage
AuditLog.log_payment_event('payment_authorized', current_user, {
  transaction_id: response["bfs_bfsTxnId"],
  amount: amount,
  ip: request.remote_ip,
  user_agent: request.user_agent
})
```

## Incident Response

### 1. Security Monitoring

**Monitor for suspicious activity:**

```ruby
class SecurityMonitor
  def self.check_suspicious_payment(payment)
    alerts = []
    
    # Multiple failed attempts
    if payment.user.failed_payments.last_hour.count > 5
      alerts << "Multiple failed payments"
    end
    
    # Unusual amount
    if payment.amount > payment.user.average_payment_amount * 10
      alerts << "Unusually large payment"
    end
    
    # Different location
    if payment.ip_country != payment.user.usual_country
      alerts << "Payment from unusual location"
    end
    
    notify_security_team(alerts) if alerts.any?
  end
end
```

### 2. Incident Response Plan

**Steps to take if security incident occurs:**

1. **Immediate Actions:**
   - Disable affected accounts
   - Revoke compromised credentials
   - Block suspicious IP addresses

2. **Investigation:**
   - Review audit logs
   - Identify scope of breach
   - Document findings

3. **Remediation:**
   - Patch vulnerabilities
   - Reset credentials
   - Notify affected users

4. **Prevention:**
   - Update security measures
   - Conduct security training
   - Review and update policies

### 3. Emergency Contacts

**Maintain emergency contact list:**

```ruby
# config/security_contacts.yml
security_team:
  primary: security@example.com
  phone: +975-XXXXXXXX

rma_support:
  email: support@rma.org.bt
  phone: +975-XXXXXXXX

incident_response:
  email: incidents@example.com
  escalation: cto@example.com
```

## Security Checklist

Before going to production:

- [ ] RSA private keys stored securely
- [ ] Environment variables configured
- [ ] HTTPS enforced
- [ ] Input validation implemented
- [ ] CSRF protection enabled
- [ ] Rate limiting configured
- [ ] Session security configured
- [ ] Audit logging implemented
- [ ] Error handling doesn't leak sensitive info
- [ ] Security monitoring in place
- [ ] Incident response plan documented
- [ ] Team trained on security practices
- [ ] Regular security audits scheduled
- [ ] Backup and recovery procedures tested

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [PCI DSS Requirements](https://www.pcisecuritystandards.org/)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)

## Support

For security concerns:
- Email: tashii.dendupp@gmail.com
- GitHub Security Advisories: https://github.com/dcplbt/rma-payment-gateway/security

