# Subscription UI Implementation Guide

## Overview
Based on the React code provided, here's the Flutter implementation plan for the subscription page.

## Key Features from React Code

1. **Subscription Status Display**
   - Current plan name (Trial, Active, Expired)
   - Days remaining with progress bar
   - Plan limits (Products, Stock Items, Transactions)

2. **Expiring Soon Alert**
   - Shows when trial/subscription is expiring (7 days or less)
   - Orange alert card with warning message

3. **Package Selection**
   - 4 buttons for 1, 3, 6, 12 months
   - Shows price, savings badge, price per month
   - Highlights current duration if active subscription

4. **Payment Flow**
   - Redirects to bcl.my payment forms
   - Different URLs for each duration

5. **Subscription History**
   - List of past subscriptions
   - Status badges
   - Dates and amounts

6. **Billing Information**
   - Payment method, provider, transaction ID
   - Amount paid

## Pricing Structure

### Standard (RM 39/month):
- 1 Bulan: RM 39
- 3 Bulan: RM 117
- 6 Bulan: RM 215.28 (8% discount)
- 12 Bulan: RM 397.80 (15% discount)

### Early Adopter (RM 29/month):
- 1 Bulan: RM 29
- 3 Bulan: RM 87
- 6 Bulan: RM 160.08 (8% discount)
- 12 Bulan: RM 295.80 (15% discount)

## BCL.my Payment URLs

```dart
const bclFormUrls = {
  1: 'https://bnidigital.bcl.my/form/1-bulan',
  3: 'https://bnidigital.bcl.my/form/3-bulan',
  6: 'https://bnidigital.bcl.my/form/6-bulan',
  12: 'https://bnidigital.bcl.my/form/12-bulan',
};
```

## UI Components Needed

1. **SubscriptionPage** - Main page
2. **ExpiringSoonAlert** - Alert card for expiring subscriptions
3. **CurrentPlanCard** - Shows current subscription status
4. **PackageSelectionGrid** - Grid of package buttons
5. **SubscriptionHistoryList** - List of past subscriptions
6. **BillingInfoCard** - Payment details

## Implementation Notes

- Use `url_launcher` package for payment redirects
- Show loading states while fetching data
- Auto-refresh subscription status every 5 seconds (optional)
- Handle payment callbacks when user returns from bcl.my
- Show early adopter badge if applicable

## Email Follow-up Setup

### Trial Reminders
- Day 1: Welcome email with feature tour
- Day 3: "How's it going?" + try consignment system
- Day 5: "Last 2 days!" + usage summary
- Day 7: "Trial ending" + upgrade CTA

### Active Subscription
- 7 days before expiry: Renewal reminder
- 3 days before expiry: Urgent renewal
- 1 day before expiry: Final reminder
- On expiry: Subscription expired notification

### Implementation Options
1. **Supabase Edge Functions** - Scheduled functions to send emails
2. **External Service** - Use email service (SendGrid, Mailgun, etc.)
3. **Database Triggers** - Trigger on subscription status changes


