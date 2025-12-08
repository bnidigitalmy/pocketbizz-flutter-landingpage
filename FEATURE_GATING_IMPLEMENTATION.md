# Feature Gating Implementation Guide

## Overview
Implement feature gating untuk restrict access based on subscription status.

## Strategy

### Trial Users (7 days)
- ✅ Full access to all features
- ⚠️ Show upgrade prompts when trial < 7 days
- ⚠️ Show upgrade prompts in key features

### Active Subscription
- ✅ Full access to all features
- ⚠️ Show renewal reminders when < 7 days before expiry

### Expired/No Subscription
- ❌ View-only mode (can view data, can't create/edit)
- ⚠️ Upgrade prompts everywhere
- ✅ Can still export data

## Implementation

### 1. SubscriptionGuard Widget
Use `SubscriptionGuard` to wrap features that require subscription:

```dart
SubscriptionGuard(
  featureName: 'Sistem Konsinyemen',
  allowTrial: true, // Trial users can access
  child: ConsignmentPage(),
)
```

### 2. SubscriptionHelper
Use helper methods for conditional logic:

```dart
final hasAccess = await SubscriptionHelper.hasActiveSubscription();
if (!hasAccess) {
  // Show upgrade prompt
}
```

## Features to Gate

### High Priority (Gate Immediately)
1. **Consignment System** ⭐
   - Create claims
   - Create payments
   - Vendor management
   - **Reason**: Core differentiator, high value feature

2. **Advanced Reports**
   - Profit & Loss reports
   - Sales by Channel
   - Top Products/Vendors analysis
   - **Reason**: Business intelligence, valuable feature

### Medium Priority (Optional)
3. **Production Planning**
   - Recipe management
   - Production scheduling
   - **Reason**: Advanced feature, not critical for basic users

4. **Multi-user Support**
   - Add team members
   - **Reason**: Enterprise feature

## Where to Add Gates

### 1. Consignment System
- `lib/features/claims/presentation/claims_page.dart`
- `lib/features/claims/presentation/create_claim_simplified_page.dart`
- `lib/features/vendors/presentation/vendors_page.dart`

### 2. Reports
- `lib/features/reports/presentation/reports_page.dart`
- Gate PDF generation for advanced reports

### 3. Production Planning
- `lib/features/production/presentation/production_planning_page.dart`
- `lib/features/recipes/presentation/recipe_builder_page.dart`

## Upgrade Prompts

### In-App Alerts
- Show banner on dashboard when trial < 7 days
- Show modal when accessing locked features
- Show inline prompts in feature pages

### Navigation
- Add "Upgrade" button in app bar
- Add subscription link in sidebar (✅ Done)
- Show subscription status in settings

## Testing Checklist

- [ ] Trial user can access all features
- [ ] Trial user sees upgrade prompts
- [ ] Active subscription user has full access
- [ ] Expired subscription user sees upgrade prompts
- [ ] Upgrade prompts redirect to subscription page
- [ ] Feature gates work correctly


