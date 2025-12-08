# PocketBizz Subscription Implementation Plan

## 📋 Overview
- **Standard Price**: RM 39/month
- **Early Adopter Price**: RM 29/month (first 100 users, lifetime)
- **Payment Gateway**: bcl.my
- **Packages**: 1 month, 3 months, 6 months, 12 months

---

## 🗄️ Database Schema

### Tables Created:
1. **subscription_plans** - Available packages
2. **subscriptions** - User subscription records
3. **subscription_payments** - Payment history
4. **early_adopters** - Track first 100 users

### Key Features:
- ✅ RLS policies for security
- ✅ Helper functions for early adopter checks
- ✅ Subscription status tracking
- ✅ Trial period support (7 days)
- ✅ Auto-renewal flag

---

## 💰 Pricing Structure

### Standard Pricing (RM 39/month):
| Package | Duration | Price/Month | Total Price | Discount | Savings |
|---------|----------|-------------|-------------|----------|---------|
| 1 Bulan | 1 month | RM 39 | RM 39.00 | - | - |
| 3 Bulan | 3 months | RM 39 | RM 117.00 | - | - |
| 6 Bulan | 6 months | RM 39 | RM 215.28 | 8% | RM 18.72 |
| 12 Bulan | 12 months | RM 39 | RM 397.80 | 15% | RM 70.20 |

### Early Adopter Pricing (RM 29/month):
| Package | Duration | Price/Month | Total Price | Discount | Savings vs Standard |
|---------|----------|-------------|-------------|----------|---------------------|
| 1 Bulan | 1 month | RM 29 | RM 29.00 | - | RM 10.00 |
| 3 Bulan | 3 months | RM 29 | RM 87.00 | - | RM 30.00 |
| 6 Bulan | 6 months | RM 29 | RM 160.08 | 8% | RM 54.92 |
| 12 Bulan | 12 months | RM 29 | RM 295.80 | 15% | RM 102.00 |

---

## 🔄 Subscription Flow

### 1. **Free Trial (7 Days)**
```
User Signs Up
    ↓
Check if early adopter slot available (< 100)
    ↓
Create subscription with status='trial'
    ↓
trial_ends_at = NOW() + 7 days
    ↓
Full feature access
```

### 2. **Trial to Paid Conversion**
```
Trial Ending (Day 7)
    ↓
User selects package (1/3/6/12 months)
    ↓
Calculate price (RM 29 if early adopter, RM 39 standard)
    ↓
Redirect to bcl.my payment
    ↓
Payment success → Update subscription
    ↓
status='active', expires_at = NOW() + duration
```

### 3. **Subscription Renewal**
```
Subscription Expiring
    ↓
If auto_renew = TRUE
    ↓
Charge via bcl.my
    ↓
Create new payment record
    ↓
Extend expires_at
```

---

## 🔌 bcl.my Payment Gateway Integration

### Required Information:
1. **API Endpoint**: Get from bcl.my documentation
2. **API Key/Secret**: For authentication
3. **Webhook URL**: For payment callbacks
4. **Return URL**: After payment completion

### Payment Flow:
```
User clicks "Subscribe"
    ↓
Create subscription record (status='pending_payment')
    ↓
Generate payment request to bcl.my
    ↓
Redirect user to bcl.my payment page
    ↓
User completes payment
    ↓
bcl.my webhook → Update subscription
    ↓
Redirect user back to app (success/failure)
```

### Webhook Handler (to implement):
- Verify payment signature
- Update subscription status
- Create payment record
- Send confirmation email

---

## 📱 Flutter Implementation Tasks

### 1. **Data Models**
- `SubscriptionPlan`
- `Subscription`
- `SubscriptionPayment`
- `EarlyAdopterStatus`

### 2. **Repositories**
- `SubscriptionRepositorySupabase`
  - `getAvailablePlans()`
  - `getUserSubscription()`
  - `startTrial()`
  - `checkEarlyAdopterStatus()`
  - `registerEarlyAdopter()`
  - `createSubscription()`
  - `updateSubscriptionStatus()`
  - `getPaymentHistory()`

### 3. **Services**
- `SubscriptionService`
  - `initializeTrial()`
  - `purchaseSubscription(planId)`
  - `handlePaymentCallback()`
  - `checkSubscriptionStatus()`
  - `cancelSubscription()`

### 4. **Payment Gateway Service**
- `BclPaymentService`
  - `initiatePayment(amount, reference)`
  - `verifyPayment(transactionId)`
  - `handleWebhook(payload)`

### 5. **UI Pages**
- `SubscriptionPage` - Show plans, pricing
- `PaymentPage` - Payment flow
- `SubscriptionStatusPage` - Current subscription details
- `PaymentHistoryPage` - Past payments

### 6. **Feature Gating**
- `SubscriptionGuard` - Check if feature accessible
- `FeatureGateWidget` - Show upgrade prompt for locked features

---

## 🎯 Feature Gating Strategy

### During Trial:
- ✅ All features unlocked
- ⚠️ Show trial countdown
- ⚠️ Show upgrade prompts

### After Trial (No Payment):
- ❌ View-only mode (read data, can't create/edit)
- ⚠️ Upgrade prompts everywhere
- ✅ Can still export data

### Active Subscription:
- ✅ Full access
- ✅ All features unlocked
- ⚠️ Show renewal date

### Expired Subscription:
- ❌ Same as no payment
- ⚠️ Urgent renewal prompts

---

## 📊 Early Adopter Logic

### Registration:
```dart
// On user signup
final isEarlyAdopter = await subscriptionRepo.checkEarlyAdopterStatus();
if (isEarlyAdopter) {
    await subscriptionRepo.registerEarlyAdopter();
    // Lock in RM 29/month pricing
}
```

### Pricing Calculation:
```dart
double calculatePrice(int durationMonths, bool isEarlyAdopter) {
    final basePrice = isEarlyAdopter ? 29.0 : 39.0;
    return basePrice * durationMonths;
}
```

---

## 🔔 User Notifications

### Trial Period:
- Day 1: Welcome email with feature tour
- Day 3: "How's it going?" + try consignment system
- Day 5: "Last 2 days!" + usage summary
- Day 7: "Trial ending" + upgrade CTA

### Active Subscription:
- 7 days before expiry: Renewal reminder
- 3 days before expiry: Urgent renewal
- 1 day before expiry: Final reminder
- On expiry: Subscription expired notification

---

## ✅ Implementation Checklist

### Phase 1: Database & Models
- [x] Create migration file
- [ ] Run migration in Supabase
- [ ] Create Dart models
- [ ] Create repository

### Phase 2: Subscription Service
- [ ] Implement trial logic
- [ ] Implement early adopter logic
- [ ] Implement subscription creation
- [ ] Implement status checking

### Phase 3: Payment Integration
- [ ] Research bcl.my API
- [ ] Implement payment service
- [ ] Create webhook handler
- [ ] Test payment flow

### Phase 4: UI Implementation
- [ ] Subscription page
- [ ] Payment page
- [ ] Status page
- [ ] Feature gates

### Phase 5: Testing
- [ ] Test trial flow
- [ ] Test payment flow
- [ ] Test early adopter logic
- [ ] Test feature gating

---

## 📝 Notes

1. **Early Adopter Limit**: First 100 users only
2. **Trial Period**: 7 days, full features
3. **Payment Gateway**: bcl.my (need API docs)
4. **Auto-renewal**: Optional, user can toggle
5. **Cancellation**: User can cancel anytime, access until expiry

---

## 🔗 Next Steps

1. Review bcl.my API documentation
2. Set up webhook endpoint
3. Implement subscription repository
4. Build UI components
5. Test end-to-end flow

