# API Documentation

This document provides detailed information about the RMA Payment Gateway API integration.

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [API Endpoints](#api-endpoints)
- [Request/Response Format](#requestresponse-format)
- [Payment Flow](#payment-flow)
- [Error Codes](#error-codes)

## Overview

The RMA Payment Gateway API uses a REST-like interface with URL-encoded form data for requests and JSON responses. All communication must be done over HTTPS.

**Base URL:** Configured via `RMA_BASE_URL` environment variable

**API Endpoint:** `/BFSSecure/nvpapi`

## Authentication

The API uses RSA key-based authentication. You must:

1. Obtain an RSA private key from RMA
2. Store the key securely
3. Configure the key path in your application

```ruby
config.rsa_key_path = '/path/to/rsa_private_key.pem'
```

## API Endpoints

All requests are sent to the same endpoint with different message types (`bfs_msgType`):

### Base Endpoint

```
POST /BFSSecure/nvpapi
Content-Type: application/x-www-form-urlencoded
```

## Request/Response Format

### Request Format

All requests are sent as URL-encoded form data:

```
bfs_param1=value1&bfs_param2=value2&bfs_param3=value3
```

### Response Format

All responses are returned as JSON:

```json
{
  "result": {
    "bfs_responseCode": "00",
    "bfs_responseDesc": "Success",
    "bfs_bfsTxnId": "TXN123456789",
    ...
  }
}
```

## Payment Flow

### 1. Payment Authorization (AR)

**Purpose:** Initiate a payment request

**Message Type:** `AR` (Authorization Request)

**Request Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `bfs_benfTxnTime` | String | Yes | Transaction timestamp (YYYYMMDDHHmmss) |
| `bfs_orderNo` | String | Yes | Unique order number |
| `bfs_benfBankCode` | String | Yes | Beneficiary bank code (default: "01") |
| `bfs_txnCurrency` | String | Yes | Transaction currency (BTN) |
| `bfs_txnAmount` | String | Yes | Transaction amount (format: "100.00") |
| `bfs_remitterEmail` | String | Yes | Customer email address |
| `bfs_paymentDesc` | String | Yes | Payment description |
| `bfs_benfId` | String | Yes | Beneficiary/Merchant ID |
| `bfs_msgType` | String | Yes | Message type ("AR") |
| `bfs_version` | String | Yes | API version ("5.0") |

**Example Request:**

```ruby
client.authorization.call(
  "ORDER123",           # order_no
  100.50,              # amount
  "customer@email.com" # email
)
```

**Example Response:**

```json
{
  "result": {
    "bfs_responseCode": "00",
    "bfs_responseDesc": "Success",
    "bfs_bfsTxnId": "TXN123456789",
    "bfs_orderNo": "ORDER123",
    "bfs_txnAmount": "100.50",
    "bfs_txnCurrency": "BTN",
    "bfs_benfTxnTime": "20231215143022"
  }
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `bfs_responseCode` | String | Response code ("00" for success) |
| `bfs_responseDesc` | String | Response description |
| `bfs_bfsTxnId` | String | Transaction ID (use for subsequent steps) |
| `bfs_orderNo` | String | Order number |
| `bfs_txnAmount` | String | Transaction amount |
| `bfs_txnCurrency` | String | Transaction currency |
| `bfs_benfTxnTime` | String | Transaction timestamp |

---

### 2. Account Inquiry (AE)

**Purpose:** Verify customer's bank account and trigger OTP

**Message Type:** `AE` (Account Enquiry)

**Request Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `bfs_bfsTxnId` | String | Yes | Transaction ID from authorization |
| `bfs_remitterBankId` | String | Yes | Customer's bank code |
| `bfs_remitterAccNo` | String | Yes | Customer's account number |
| `bfs_benfId` | String | Yes | Beneficiary/Merchant ID |
| `bfs_msgType` | String | Yes | Message type ("AE") |

**Example Request:**

```ruby
client.account_inquiry.call(
  "TXN123456789",  # transaction_id
  "1010",          # bank_id
  "12345678"       # account_no
)
```

**Example Response:**

```json
{
  "result": {
    "bfs_responseCode": "00",
    "bfs_responseDesc": "Success",
    "bfs_bfsTxnId": "TXN123456789",
    "bfs_remitterName": "John Doe",
    "bfs_remitterAccNo": "12345678",
    "bfs_remitterBankId": "1010"
  }
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `bfs_responseCode` | String | Response code ("00" for success) |
| `bfs_responseDesc` | String | Response description |
| `bfs_bfsTxnId` | String | Transaction ID |
| `bfs_remitterName` | String | Account holder name |
| `bfs_remitterAccNo` | String | Account number |
| `bfs_remitterBankId` | String | Bank code |

**Note:** After successful account inquiry, an OTP is sent to the customer's registered mobile number.

---

### 3. Debit Request (DR)

**Purpose:** Complete the payment transaction with OTP

**Message Type:** `DR` (Debit Request)

**Request Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `bfs_bfsTxnId` | String | Yes | Transaction ID from authorization |
| `bfs_remitterOtp` | String | Yes | OTP received by customer |
| `bfs_benfId` | String | Yes | Beneficiary/Merchant ID |
| `bfs_msgType` | String | Yes | Message type ("DR") |

**Example Request:**

```ruby
client.debit_request.call(
  "TXN123456789",  # transaction_id
  "123456"         # otp
)
```

**Example Response:**

```json
{
  "result": {
    "bfs_responseCode": "00",
    "bfs_responseDesc": "Transaction Successful",
    "bfs_bfsTxnId": "TXN123456789",
    "bfs_txnAmount": "100.50",
    "bfs_orderNo": "ORDER123",
    "bfs_txnCurrency": "BTN"
  }
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `bfs_responseCode` | String | Response code ("00" for success) |
| `bfs_responseDesc` | String | Response description |
| `bfs_bfsTxnId` | String | Transaction ID |
| `bfs_txnAmount` | String | Transaction amount |
| `bfs_orderNo` | String | Order number |
| `bfs_txnCurrency` | String | Transaction currency |

---

## Error Codes

### Response Codes

| Code | Description | Action Required |
|------|-------------|-----------------|
| `00` | Success | Transaction completed successfully |
| `01` | Invalid request | Check request parameters |
| `02` | Invalid beneficiary | Verify beneficiary ID configuration |
| `03` | Invalid transaction | Check transaction ID |
| `04` | Insufficient funds | Customer needs to add funds |
| `05` | Invalid OTP | Customer should re-enter OTP |
| `06` | OTP expired | Restart the transaction |
| `07` | Transaction timeout | Restart the transaction |
| `08` | Account blocked | Customer should contact their bank |
| `09` | Invalid account | Verify account number |
| `10` | Service unavailable | Retry later |
| `99` | System error | Contact RMA support |

### HTTP Status Codes

| Status | Description | Gem Exception |
|--------|-------------|---------------|
| 200 | Success | - |
| 400 | Bad Request | `InvalidParameterError` |
| 401 | Unauthorized | `AuthenticationError` |
| 403 | Forbidden | `AuthenticationError` |
| 404 | Not Found | `APIError` |
| 422 | Unprocessable Entity | `InvalidParameterError` |
| 500 | Internal Server Error | `APIError` |
| 502 | Bad Gateway | `NetworkError` |
| 503 | Service Unavailable | `NetworkError` |
| 504 | Gateway Timeout | `NetworkError` |

## Bank Codes

Supported banks in Bhutan:

| Code | Bank Name | Abbreviation |
|------|-----------|--------------|
| 1010 | Bank of Bhutan | BOBL |
| 1020 | Bhutan National Bank | BNBL |
| 1030 | Druk PNB Bank Limited | DPNBL |
| 1040 | Tashi Bank | TBank |
| 1050 | Bhutan Development Bank Limited | BDBL |
| 1060 | Digital Kidu | DK Bank |

## Best Practices

### 1. Transaction ID Management

- Store transaction IDs securely
- Use transaction IDs for reconciliation
- Keep transaction logs for audit purposes

### 2. Error Handling

- Always handle all exception types
- Log errors with masked sensitive data
- Provide user-friendly error messages

### 3. Timeout Handling

- Set appropriate timeout values
- Implement retry logic for network errors
- Don't retry on validation errors

### 4. Security

- Never log sensitive data (OTP, account numbers)
- Use HTTPS for all communications
- Validate all inputs before sending to API
- Store RSA keys securely

### 5. Testing

- Test with small amounts first
- Verify all three steps of the flow
- Test error scenarios
- Implement idempotency for retries

## Rate Limiting

The API may implement rate limiting. Best practices:

- Implement exponential backoff for retries
- Cache transaction results
- Don't make duplicate requests
- Monitor API usage

## Support

For API-related issues:

- Check error codes and messages
- Review request/response logs
- Contact RMA technical support
- Email: tashii.dendupp@gmail.com

