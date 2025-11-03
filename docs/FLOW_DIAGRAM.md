# Payment Flow Diagrams

This document provides visual representations of the RMA Payment Gateway payment flow.

## Table of Contents

- [Complete Payment Flow](#complete-payment-flow)
- [Step-by-Step Flow](#step-by-step-flow)
- [Error Handling Flow](#error-handling-flow)
- [Sequence Diagrams](#sequence-diagrams)

## Complete Payment Flow

```
┌─────────────┐
│   Merchant  │
│ Application │
└──────┬──────┘
       │
       │ 1. Initiate Payment
       │    - Order Number
       │    - Amount
       │    - Customer Email
       ▼
┌─────────────────────────────────┐
│  RMA Payment Gateway Client     │
│  .authorization.call()          │
└──────────┬──────────────────────┘
           │
           │ POST /BFSSecure/nvpapi
           │ bfs_msgType=AR
           ▼
┌─────────────────────────────────┐
│   RMA Payment Gateway API       │
└──────────┬──────────────────────┘
           │
           │ Returns Transaction ID
           ▼
┌─────────────────────────────────┐
│  Merchant Application           │
│  Store Transaction ID           │
└──────────┬──────────────────────┘
           │
           │ 2. Customer Provides
           │    - Bank ID
           │    - Account Number
           ▼
┌─────────────────────────────────┐
│  RMA Payment Gateway Client     │
│  .account_inquiry.call()        │
└──────────┬──────────────────────┘
           │
           │ POST /BFSSecure/nvpapi
           │ bfs_msgType=AE
           ▼
┌─────────────────────────────────┐
│   RMA Payment Gateway API       │
│   - Verify Account              │
│   - Send OTP to Customer        │
└──────────┬──────────────────────┘
           │
           │ Returns Account Info
           ▼
┌─────────────────────────────────┐
│  Customer Receives OTP          │
│  (via SMS to registered mobile) │
└──────────┬──────────────────────┘
           │
           │ 3. Customer Provides OTP
           ▼
┌─────────────────────────────────┐
│  RMA Payment Gateway Client     │
│  .debit_request.call()          │
└──────────┬──────────────────────┘
           │
           │ POST /BFSSecure/nvpapi
           │ bfs_msgType=DR
           ▼
┌─────────────────────────────────┐
│   RMA Payment Gateway API       │
│   - Verify OTP                  │
│   - Process Payment             │
│   - Debit Customer Account      │
└──────────┬──────────────────────┘
           │
           │ Returns Payment Confirmation
           ▼
┌─────────────────────────────────┐
│  Merchant Application           │
│  - Mark Order as Paid           │
│  - Send Confirmation to Customer│
└─────────────────────────────────┘
```

## Step-by-Step Flow

### Step 1: Payment Authorization

```
┌──────────┐                    ┌──────────┐                    ┌──────────┐
│ Merchant │                    │   Gem    │                    │   RMA    │
│   App    │                    │  Client  │                    │   API    │
└────┬─────┘                    └────┬─────┘                    └────┬─────┘
     │                               │                               │
     │ authorization.call()          │                               │
     │ - order_no: "ORDER123"        │                               │
     │ - amount: 100.50              │                               │
     │ - email: "user@example.com"   │                               │
     ├──────────────────────────────>│                               │
     │                               │                               │
     │                               │ POST /BFSSecure/nvpapi        │
     │                               │ bfs_msgType=AR                │
     │                               │ bfs_orderNo=ORDER123          │
     │                               │ bfs_txnAmount=100.50          │
     │                               │ bfs_remitterEmail=user@...    │
     │                               ├──────────────────────────────>│
     │                               │                               │
     │                               │                               │ Validate
     │                               │                               │ Request
     │                               │                               │
     │                               │ Response                      │
     │                               │ bfs_bfsTxnId=TXN123          │
     │                               │ bfs_responseCode=00           │
     │                               │<──────────────────────────────┤
     │                               │                               │
     │ Return Response               │                               │
     │ transaction_id: "TXN123"      │                               │
     │<──────────────────────────────┤                               │
     │                               │                               │
     │ Store Transaction ID          │                               │
     │                               │                               │
```

### Step 2: Account Inquiry

```
┌──────────┐                    ┌──────────┐                    ┌──────────┐
│ Merchant │                    │   Gem    │                    │   RMA    │
│   App    │                    │  Client  │                    │   API    │
└────┬─────┘                    └────┬─────┘                    └────┬─────┘
     │                               │                               │
     │ account_inquiry.call()        │                               │
     │ - transaction_id: "TXN123"    │                               │
     │ - bank_id: "1010"             │                               │
     │ - account_no: "12345678"      │                               │
     ├──────────────────────────────>│                               │
     │                               │                               │
     │                               │ POST /BFSSecure/nvpapi        │
     │                               │ bfs_msgType=AE                │
     │                               │ bfs_bfsTxnId=TXN123          │
     │                               │ bfs_remitterBankId=1010       │
     │                               │ bfs_remitterAccNo=12345678    │
     │                               ├──────────────────────────────>│
     │                               │                               │
     │                               │                               │ Verify
     │                               │                               │ Account
     │                               │                               │
     │                               │                               │ Send OTP
     │                               │                               │ to Customer
     │                               │                               │
     │                               │ Response                      │
     │                               │ bfs_remitterName=John Doe     │
     │                               │ bfs_responseCode=00           │
     │                               │<──────────────────────────────┤
     │                               │                               │
     │ Return Response               │                               │
     │ account_name: "John Doe"      │                               │
     │<──────────────────────────────┤                               │
     │                               │                               │
     │ Display Account Info          │                               │
     │ Request OTP from Customer     │                               │
     │                               │                               │
```

### Step 3: Debit Request

```
┌──────────┐                    ┌──────────┐                    ┌──────────┐
│ Merchant │                    │   Gem    │                    │   RMA    │
│   App    │                    │  Client  │                    │   API    │
└────┬─────┘                    └────┬─────┘                    └────┬─────┘
     │                               │                               │
     │ debit_request.call()          │                               │
     │ - transaction_id: "TXN123"    │                               │
     │ - otp: "123456"               │                               │
     ├──────────────────────────────>│                               │
     │                               │                               │
     │                               │ POST /BFSSecure/nvpapi        │
     │                               │ bfs_msgType=DR                │
     │                               │ bfs_bfsTxnId=TXN123          │
     │                               │ bfs_remitterOtp=123456        │
     │                               ├──────────────────────────────>│
     │                               │                               │
     │                               │                               │ Verify
     │                               │                               │ OTP
     │                               │                               │
     │                               │                               │ Process
     │                               │                               │ Payment
     │                               │                               │
     │                               │                               │ Debit
     │                               │                               │ Account
     │                               │                               │
     │                               │ Response                      │
     │                               │ bfs_responseCode=00           │
     │                               │ bfs_txnAmount=100.50          │
     │                               │<──────────────────────────────┤
     │                               │                               │
     │ Return Response               │                               │
     │ payment_status: "completed"   │                               │
     │<──────────────────────────────┤                               │
     │                               │                               │
     │ Mark Order as Paid            │                               │
     │ Send Confirmation             │                               │
     │                               │                               │
```

## Error Handling Flow

```
┌──────────────────────────────────────────────────────────────┐
│                    Payment Request                           │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
                  ┌──────────────┐
                  │  Validate    │
                  │  Input       │
                  └──────┬───────┘
                         │
                    ┌────┴────┐
                    │ Valid?  │
                    └────┬────┘
                         │
              ┌──────────┴──────────┐
              │                     │
             Yes                   No
              │                     │
              ▼                     ▼
      ┌──────────────┐      ┌─────────────────────┐
      │ Send Request │      │ InvalidParameterError│
      │ to RMA API   │      │ Return Error to User │
      └──────┬───────┘      └─────────────────────┘
             │
             ▼
      ┌──────────────┐
      │ API Response │
      └──────┬───────┘
             │
        ┌────┴────┐
        │Response │
        │ Code?   │
        └────┬────┘
             │
    ┌────────┼────────┐
    │        │        │
   "00"    Other    Error
    │        │        │
    ▼        ▼        ▼
┌────────┐ ┌──────┐ ┌──────────────┐
│Success │ │Retry?│ │ Raise Error  │
│        │ │      │ │ - Network    │
│        │ │      │ │ - Auth       │
│        │ │      │ │ - API        │
└────────┘ └──────┘ └──────────────┘
```

## Sequence Diagrams

### Complete Payment Sequence

```
Customer    Merchant    Gem Client    RMA API    Bank
   │           │            │            │         │
   │  Browse   │            │            │         │
   │  & Order  │            │            │         │
   ├──────────>│            │            │         │
   │           │            │            │         │
   │           │ Step 1: Authorization   │         │
   │           ├───────────>│            │         │
   │           │            ├───────────>│         │
   │           │            │<───────────┤         │
   │           │<───────────┤            │         │
   │           │ (TXN ID)   │            │         │
   │           │            │            │         │
   │  Provide  │            │            │         │
   │  Bank     │            │            │         │
   │  Details  │            │            │         │
   ├──────────>│            │            │         │
   │           │            │            │         │
   │           │ Step 2: Account Inquiry │         │
   │           ├───────────>│            │         │
   │           │            ├───────────>│         │
   │           │            │            ├────────>│
   │           │            │            │ Verify  │
   │           │            │            │<────────┤
   │<──────────┼────────────┼────────────┤         │
   │  OTP SMS  │            │            │         │
   │           │            │<───────────┤         │
   │           │<───────────┤            │         │
   │           │ (Account   │            │         │
   │           │  Info)     │            │         │
   │           │            │            │         │
   │  Enter    │            │            │         │
   │  OTP      │            │            │         │
   ├──────────>│            │            │         │
   │           │            │            │         │
   │           │ Step 3: Debit Request   │         │
   │           ├───────────>│            │         │
   │           │            ├───────────>│         │
   │           │            │            ├────────>│
   │           │            │            │ Debit   │
   │           │            │            │<────────┤
   │           │            │<───────────┤         │
   │           │<───────────┤            │         │
   │           │ (Success)  │            │         │
   │           │            │            │         │
   │<──────────┤            │            │         │
   │Confirmation            │            │         │
   │           │            │            │         │
```

## State Diagram

```
┌─────────────┐
│   Pending   │ Initial state
└──────┬──────┘
       │
       │ authorization.call()
       ▼
┌─────────────┐
│ Authorized  │ Transaction ID received
└──────┬──────┘
       │
       │ account_inquiry.call()
       ▼
┌─────────────┐
│  Account    │ OTP sent to customer
│  Verified   │
└──────┬──────┘
       │
       │ debit_request.call()
       ▼
┌─────────────┐
│  Completed  │ Payment successful
└─────────────┘

       │
       │ (Any step can fail)
       ▼
┌─────────────┐
│   Failed    │ Error occurred
└─────────────┘
```

## Integration Patterns

### Pattern 1: Synchronous Flow

```
User Action → Authorization → Account Inquiry → Debit Request → Completion
     │              │               │                │              │
     └──────────────┴───────────────┴────────────────┴──────────────┘
                    All steps in same session
```

### Pattern 2: Asynchronous Flow

```
User Action → Authorization → Store State
                                    │
Customer Returns → Account Inquiry → Store State
                                          │
Customer Enters OTP → Debit Request → Completion
```

### Pattern 3: Background Job Flow

```
User Action → Queue Job → Authorization
                              │
                              ▼
                         Queue Job → Account Inquiry
                                         │
                                         ▼
                                    Queue Job → Debit Request
```

## Error Recovery Flow

```
┌─────────────┐
│   Attempt   │
│   Payment   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Error?    │
└──────┬──────┘
       │
   ┌───┴───┐
   │       │
  Yes     No
   │       │
   ▼       ▼
┌──────┐ ┌────────┐
│Error │ │Success │
│Type? │ └────────┘
└──┬───┘
   │
   ├─ Network Error ──> Retry with backoff
   │
   ├─ Invalid Param ──> Show error to user
   │
   ├─ Auth Error ────> Check config, retry
   │
   ├─ OTP Error ─────> Allow re-entry
   │
   └─ Other Error ───> Log & notify admin
```

## Best Practices

1. **Always store transaction ID** after authorization
2. **Validate inputs** before each API call
3. **Handle all error types** appropriately
4. **Implement timeouts** for each step
5. **Log all transactions** (with masked sensitive data)
6. **Provide clear feedback** to users at each step
7. **Implement retry logic** for network errors only
8. **Never retry** validation or authentication errors

## Related Documentation

- [API Documentation](API.md) - Detailed API reference
- [Usage Guide](USAGE_GUIDE.md) - Integration examples
- [Code Examples](EXAMPLES.md) - Practical code samples
- [Security Guide](SECURITY.md) - Security best practices

