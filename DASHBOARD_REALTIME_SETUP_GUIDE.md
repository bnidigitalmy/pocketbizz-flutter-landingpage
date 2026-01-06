# 🚀 Dashboard Real-Time Setup Guide

## ✅ Step 1: Enable Realtime in Supabase

### Option A: Via Supabase Dashboard (Recommended)

1. **Open Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your project

2. **Open SQL Editor**
   - Click **"SQL Editor"** in left sidebar
   - Click **"New query"**

3. **Run Migration**
   - Open file: `db/migrations/2025-01-16_enable_realtime_for_dashboard.sql`
   - Copy **ALL** contents
   - Paste into SQL Editor
   - Click **"Run"** ▶️

4. **Verify Success**
   - Should see: `Success. No rows returned`
   - No errors = ✅ Success!

### Option B: Via Supabase CLI

```bash
# Make sure you're in the project directory
cd "D:\BNI DIGITAL OFFICIAL\16 POCKETBIZZ - FLUTTER\PocketBizz Final\Pocketbizz-V2-Encore-1"

# Run migration
supabase db push
```

---

## 📋 Tables Enabled for Realtime

After running the migration, these tables will have real-time enabled:

| Table | Purpose | Affects Dashboard |
|-------|---------|-------------------|
| `sales` | Direct sales | Masuk, Untung |
| `sale_items` | Sales line items | Kos (Production Cost) |
| `bookings` | Customer bookings | Masuk (when completed) |
| `booking_items` | Booking line items | Kos |
| `consignment_claims` | Vendor claims | Masuk (when settled) |
| `consignment_claim_items` | Claim line items | Kos |
| `expenses` | Business expenses | Belanja |
| `products` | Product catalog | Kos (if cost_per_unit changes) |
| `stock_items` | Inventory stock | Low Stock Alerts |
| `purchase_orders` | Purchase orders | Pending Tasks |

---

## 🧪 Verify Realtime is Enabled

### Method 1: SQL Query

Run this in Supabase SQL Editor:

```sql
SELECT schemaname, tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
```

**Expected Result:** Should list all 10 tables above.

### Method 2: Test in App

1. **Run Flutter App**
   ```bash
   flutter run
   ```

2. **Open Dashboard**
   - Login to app
   - Navigate to Dashboard

3. **Check Console Logs**
   - Look for: `✅ Dashboard real-time subscriptions setup complete`
   - If you see this = ✅ Realtime working!

4. **Test Real-Time Update**
   - Open Dashboard (note current values)
   - Open another tab (Sales/Expenses)
   - Create new sale/expense
   - Return to Dashboard
   - **Expected:** Values update automatically within 1-2 seconds

---

## ⚠️ Troubleshooting

### Issue: Real-time not working

**Check 1: Realtime Enabled?**
```sql
-- Run in SQL Editor
SELECT tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename IN ('sales', 'expenses', 'bookings');
```

If empty → Run migration again.

**Check 2: RLS Policies**
- Go to **Database** → **Tables**
- Click on `sales` table
- Go to **Policies** tab
- Ensure SELECT policy exists for authenticated users

**Check 3: Console Errors**
- Check Flutter console for:
  - `⚠️ Error setting up dashboard real-time subscriptions: [error]`
- If error exists, check error message

**Check 4: Supabase Realtime Status**
- Go to **Settings** → **API**
- Scroll to **Realtime** section
- Ensure **Realtime** is enabled for your project

---

## 📝 Notes

1. **Realtime is Free** on Supabase Free tier
   - Up to 200 concurrent connections
   - Unlimited messages per second
   - Perfect for SME dashboard!

2. **Debounce Delay**
   - Dashboard refreshes 1 second after last change
   - Prevents excessive updates
   - Can adjust in `dashboard_page_optimized.dart`:
     ```dart
     Timer(const Duration(milliseconds: 1000), ...) // Change 1000 to your preferred delay
     ```

3. **Performance**
   - Real-time subscriptions are lightweight
   - Only triggers when data changes
   - No polling = Better battery life!

---

## ✅ Success Checklist

- [ ] Migration file created
- [ ] Migration run in Supabase SQL Editor
- [ ] Verified tables enabled (SQL query)
- [ ] App tested with real-time updates
- [ ] Console shows success message
- [ ] Dashboard auto-updates when data changes

---

## 🎉 Done!

Your dashboard now has **real-time updates**! 🚀

No more manual refresh needed - metrics update automatically when:
- New sales created
- Expenses added
- Bookings completed
- Products updated
- And more!

