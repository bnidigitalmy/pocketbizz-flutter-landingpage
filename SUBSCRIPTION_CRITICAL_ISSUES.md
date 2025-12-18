# 🚨 SUBSCRIPTION SYSTEM - CRITICAL ISSUES LIST

**Date:** 2025-01-16  
**Status:** Issues yang perlu fix segera sebelum production

---

## 🔴 CRITICAL ISSUES (MUST FIX)

### 1. Grace Period Users Blocked ❌
**Location:** `lib/features/subscription/widgets/subscription_guard.dart:43-57`

**Problem:**
- Grace period users (7 hari lepas expiry) tidak boleh access gated features
- `SubscriptionGuard` hanya check `active` status, tapi `isActive` property include grace
- Users yang dalam grace period sepatutnya masih boleh guna app

**Impact:** Users kehilangan akses 7 hari sebelum benar-benar expired

**Fix Required:**
```dart
// Current (WRONG):
if (subscription.status == SubscriptionStatus.active) return true;

// Should be:
if (subscription.isActive) return true; // includes grace period
```

**Priority:** 🔴 **CRITICAL** - Blocking users from paid features

---

### 2. Usage Limits NOT Enforced ❌
**Location:** Multiple places (product creation, stock creation, sales creation)

**Problem:**
- Limits ditunjukkan dalam UI tapi **TIDAK dikuatkuasa**
- Trial/expired users boleh create unlimited products, stock items, transactions
- `getPlanLimits()` calculate limits tapi tidak check sebelum create

**Current Limits:**
- **Active:** Unlimited (999999)
- **Trial/Expired:** Products: 50, Stock: 100, Transactions: 100

**Impact:** 
- Business model broken - users boleh guna unlimited tanpa pay
- Revenue loss potential

**Fix Required:**
Add validation checks in:
1. `lib/features/products/presentation/add_product_page.dart`
2. `lib/features/stock/presentation/stock_page.dart` 
3. `lib/features/sales/presentation/create_sale_page_enhanced.dart`

```dart
// Before creating product
final limits = await subscriptionService.getPlanLimits();
if (limits.products.current >= limits.products.max && !limits.products.isUnlimited) {
  throw Exception('Had produk tercapai. Sila upgrade langganan anda.');
}
```

**Priority:** 🔴 **CRITICAL** - Revenue impact

---

### 3. Fixed 30 Days Per Month (Inaccurate Duration) ❌
**Location:** Multiple places in `subscription_repository_supabase.dart`

**Problem:**
```dart
final expiresAt = now.add(Duration(days: plan.durationMonths * 30));
```

**Impact:**
- 1 bulan = 30 hari (sepatutnya 28-31 hari calendar)
- 3 bulan = 90 hari (sepatutnya ~91 hari)
- 6 bulan = 180 hari (sepatutnya ~183 hari)
- 12 bulan = 360 hari (sepatutnya ~365 hari)

Users dapat **5 hari kurang** untuk 12 bulan plan!

**Fix Required:**
```dart
// Use calendar months
final expiresAt = DateTime(
  now.year,
  now.month + plan.durationMonths,
  now.day,
);
```

**Priority:** 🔴 **CRITICAL** - Accuracy & customer satisfaction

---

### 4. No Trial Reuse Prevention ❌
**Location:** `lib/features/subscription/data/repositories/subscription_repository_supabase.dart:200-265`

**Problem:**
- `startTrial()` hanya check existing active/trial subscription
- Kalau user dah pernah ada trial dan expired, boleh start trial baru lagi
- No tracking untuk past trial usage

**Impact:** Users boleh abuse system untuk dapat multiple free trials

**Fix Required:**
```sql
-- Migration needed
ALTER TABLE subscriptions 
ADD COLUMN IF NOT EXISTS has_ever_had_trial BOOLEAN DEFAULT FALSE;

-- Update startTrial() to check this flag
```

**Priority:** 🔴 **CRITICAL** - Business rule violation

---

### 5. Grace Transition Email Sent on Every Read ❌
**Location:** `lib/features/subscription/data/repositories/subscription_repository_supabase.dart:1141-1151`

**Problem:**
- `_applyGraceTransitions()` dipanggil pada setiap `getUserSubscription()` read
- Grace reminder email dihantar setiap kali status transition ke grace
- Kalau dipanggil multiple times, multiple emails dihantar

**Impact:** Users dapat duplicate/spam emails

**Fix Required:**
```sql
-- Migration needed
ALTER TABLE subscriptions 
ADD COLUMN IF NOT EXISTS grace_email_sent BOOLEAN DEFAULT FALSE;

-- Only send email if grace_email_sent = false
```

**Priority:** 🔴 **CRITICAL** - User experience & email spam

---

## 🟡 HIGH PRIORITY ISSUES

### 6. Auto-renewal NOT Implemented ⚠️
**Location:** `subscriptions.auto_renew` field exists but unused

**Problem:**
- Field ada dalam database dan model
- Tiada cron job atau scheduled task untuk auto-renew
- Tiada UI untuk enable/disable auto-renewal

**Impact:** Users kena manually renew setiap kali - poor UX

**Fix Required:**
- Implement cron job untuk check expiring subscriptions
- Process auto-renewal untuk users dengan `auto_renew = true`
- Send notification sebelum auto-renewal
- Add UI toggle untuk enable/disable

**Priority:** 🟡 **HIGH** - Feature missing

---

### 7. Payment Retry No Limit ⚠️
**Location:** `lib/features/subscription/data/repositories/subscription_repository_supabase.dart:1024-1091`

**Problem:**
- `retryPayment()` increment `retry_count` tapi tiada limit
- Users boleh retry indefinitely
- Potential untuk abuse

**Impact:** Many pending payments, database clutter

**Fix Required:**
```dart
// Add max retry limit (e.g., 5 attempts)
if (payment.retryCount >= 5) {
  throw Exception('Maximum retry attempts reached. Please contact support.');
}
```

**Priority:** 🟡 **HIGH** - Prevent abuse

---

### 8. Grace/Expiry Transitions Called on Every Read ⚠️
**Location:** `lib/features/subscription/data/repositories/subscription_repository_supabase.dart:1093-1176`

**Problem:**
- `_applyGraceTransitions()` dipanggil pada setiap `getUserSubscription()` read
- Update database pada read operation (write operation)
- Boleh cause contention under load
- Performance issue

**Impact:** 
- Database write operations pada read path
- Potential performance bottleneck
- High database load

**Fix Required:**
- Move grace/expiry transitions ke scheduled job (cron)
- Run every hour atau daily
- Remove dari `getUserSubscription()`

**Priority:** 🟡 **HIGH** - Performance

---

### 9. Extend Subscription Validation Missing ⚠️
**Location:** `lib/features/subscription/data/repositories/subscription_repository_supabase.dart:522-598`

**Problem:**
- `createPendingPaymentSession()` accept `isExtend` flag
- Tiada validation yang user ada active subscription bila `isExtend=true`
- Boleh create extend payment untuk expired subscription

**Impact:** Potential logic errors, unclear behavior

**Fix Required:**
```dart
if (isExtend) {
  final currentSub = await getUserSubscription();
  if (currentSub == null || currentSub.status != SubscriptionStatus.active) {
    throw Exception('No active subscription to extend');
  }
}
```

**Priority:** 🟡 **HIGH** - Data integrity

---

### 10. Polling Stops After 30s ⚠️
**Location:** `lib/features/subscription/presentation/payment_success_page.dart:283-297`

**Problem:**
- Polling stops after 30 seconds
- Kalau webhook delayed, user mungkin tidak nampak success
- Poor UX untuk delayed payments

**Impact:** Users tidak tahu payment status kalau webhook lambat

**Fix Required:**
- Add manual "Check Status" button
- Atau extend polling time
- Atau show message untuk user manually check later

**Priority:** 🟡 **HIGH** - User experience

---

## 🟢 MEDIUM PRIORITY ISSUES

### 11. Receipt Generation Non-blocking
- Receipt generation fails silently
- No retry mechanism
- Users mungkin tidak dapat receipt

**Fix:** Add retry queue atau better error handling

---

### 12. Email Notification Errors Ignored
- Email failures tidak surfaced ke user/admin
- Important emails mungkin tidak sampai

**Fix:** Add retry queue atau admin notification untuk failed emails

---

### 13. SubscriptionGuard No Real-time Updates
- Only checks on widget build
- Users boleh continue guna features walaupun subscription expired

**Fix:** Add Supabase Realtime subscription atau periodic refresh

---

### 14. Admin Manual Activation No Validation
- Doesn't check if user already has active subscription
- Boleh create duplicate active subscriptions

**Fix:** Expire existing subscriptions sebelum create new one

---

## 📊 SUMMARY

**Total Issues:** 14
- 🔴 **Critical:** 5 issues (MUST FIX sebelum production)
- 🟡 **High Priority:** 5 issues (Should fix soon)
- 🟢 **Medium Priority:** 4 issues (Nice to have)

### Critical Fixes Checklist

- [ ] Fix grace period access in SubscriptionGuard
- [ ] Add usage limit enforcement (products, stock, sales)
- [ ] Fix calendar months calculation (30 days → calendar months)
- [ ] Prevent trial reuse (add has_ever_had_trial flag)
- [ ] Prevent duplicate grace emails (add grace_email_sent flag)

### High Priority Fixes Checklist

- [ ] Implement auto-renewal system
- [ ] Add payment retry limit (max 5 attempts)
- [ ] Move grace/expiry transitions to cron job
- [ ] Add extend subscription validation
- [ ] Add manual "Check Status" button in PaymentSuccessPage

---

## 🎯 RECOMMENDED ACTION PLAN

### Phase 1: Critical Fixes (Week 1)
1. Fix grace period access (1 hour)
2. Add usage limit enforcement (1 day)
3. Fix calendar months calculation (2 hours)
4. Prevent trial reuse (2 hours)
5. Prevent duplicate grace emails (1 hour)

### Phase 2: High Priority Fixes (Week 2)
6. Add payment retry limit (2 hours)
7. Move transitions to cron (1 day)
8. Add extend validation (2 hours)
9. Add manual status check (2 hours)

### Phase 3: Auto-renewal (Week 3-4)
10. Design auto-renewal flow
11. Implement cron job
12. Add UI toggle
13. Testing & deployment

---

**Last Updated:** 2025-01-16
