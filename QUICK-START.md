# 🚀 PocketBizz Migration - Quick Start Checklist

**Goal: Get your app LIVE in 2-3 hours!**

---

## ✅ **Step 1: Create Supabase Project** (5 mins)

1. Go to https://supabase.com/dashboard
2. Click **"New Project"**
3. Fill in:
   - Name: `pocketbizz-v2`
   - Database Password: (Generate & SAVE IT!)
   - Region: **Southeast Asia (Singapore)**
   - Plan: **Free** (for now)
4. Click **"Create new project"**
5. ⏳ Wait 2-3 minutes

---

## ✅ **Step 2: Apply Database Schema** (5 mins)

1. In Supabase Dashboard, go to **SQL Editor**
2. Click **"New query"**
3. Open `db/schema.sql` from this project
4. Copy ALL contents (722 lines)
5. Paste into SQL Editor
6. Click **"Run"** ▶️
7. Verify: Go to **Database** → **Tables**
   - ✅ Should see: bookings, products, customers, etc.

---

## ✅ **Step 3: Get API Credentials** (2 mins)

1. In Supabase Dashboard, go to **Settings** → **API**
2. Copy these 3 values:

```
Project URL: https://xxxxx.supabase.co
anon public key: eyJhbGc...
service_role key: eyJhbGc... (keep secret!)
```

3. Save them somewhere safe!

---

## ✅ **Step 4: Setup Flutter App** (10 mins)

### A) Copy Migration Files

```bash
# Copy Flutter migration files to your Flutter project
cp -r flutter-migration/lib/* YOUR_FLUTTER_PROJECT/lib/
cp flutter-migration/pubspec.yaml YOUR_FLUTTER_PROJECT/
```

### B) Install Dependencies

```bash
cd YOUR_FLUTTER_PROJECT
flutter pub get
```

### C) Update `lib/main.dart`

Replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with your actual values:

```dart
await SupabaseConfig.initialize(
  url: 'https://xxxxx.supabase.co',  // 👈 Your URL here
  anonKey: 'eyJhbGc...',              // 👈 Your anon key here
);
```

---

## ✅ **Step 5: Test Locally** (10 mins)

```bash
# Run the app
flutter run
```

### Test Checklist:

1. **Sign Up**
   - Create new account
   - Check email for verification (if enabled)

2. **Sign In**
   - Login with created account
   - Should navigate to home screen

3. **Create Booking**
   ```dart
   final bookingsService = BookingsService();
   final booking = await bookingsService.createBooking(
     customerName: 'Test Customer',
     customerPhone: '0123456789',
     eventType: 'Wedding',
     deliveryDate: '2025-12-01',
     items: [
       {
         'product_id': 'create-product-first',
         'product_name': 'Test Product',
         'quantity': 1,
         'unit_price': 100.0,
       },
     ],
     totalAmount: 100.0,
   );
   ```

4. **List Bookings**
   ```dart
   final bookings = await bookingsService.listBookings();
   print('Total bookings: ${bookings.length}');
   ```

5. **Verify RLS**
   - Create 2 users
   - Each should only see their own data
   - ✅ If user A can't see user B's bookings = RLS works!

---

## ✅ **Step 6: Deploy to Production** (30 mins)

### Android

```bash
# Build release APK
flutter build apk --release

# OR build App Bundle for Play Store
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

Upload to **Google Play Console**:
1. Go to https://play.google.com/console
2. Create new app (if not exists)
3. Upload AAB file
4. Submit for review

### iOS

```bash
# Build for iOS
flutter build ipa --release

# Output: build/ios/ipa/*.ipa
```

Upload to **App Store Connect**:
1. Open Xcode
2. Go to **Product** → **Archive**
3. Upload to App Store Connect
4. Submit for review

---

## ✅ **Step 7: Monitor & Optimize** (Ongoing)

### Supabase Dashboard

1. **API Usage**
   - Go to **Settings** → **Usage**
   - Monitor requests/day

2. **Database Size**
   - Check storage usage
   - Upgrade to Pro when needed ($25/month)

3. **Logs**
   - Go to **Logs**
   - Check for errors

### Performance Tips

```dart
// ✅ Good: Fetch only needed columns
await supabase.from('bookings').select('id, customer_name, status');

// ❌ Bad: Fetch everything
await supabase.from('bookings').select('*');

// ✅ Good: Add pagination
await supabase.from('bookings').select().range(0, 20);

// ✅ Good: Filter on server
await supabase.from('bookings').select().eq('status', 'pending');
```

---

## 🎉 **SUCCESS CRITERIA**

Your app is LIVE when:

- ✅ Users can sign up/login
- ✅ Users can create bookings
- ✅ Users can only see their own data (RLS working)
- ✅ App is published on Play Store/App Store
- ✅ No critical errors in Supabase logs

---

## 🆘 **Troubleshooting**

### Issue: "JWT expired"
**Fix**: Supabase auto-refreshes tokens. Update to latest SDK:
```yaml
supabase_flutter: ^2.3.4
```

### Issue: "Row Level Security" error
**Fix**: Check RLS policies in Supabase Dashboard
```sql
-- Verify policy exists
SELECT * FROM pg_policies WHERE tablename = 'bookings';
```

### Issue: "permission denied for table"
**Fix**: Enable RLS and create policies
```sql
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bookings"
ON bookings FOR SELECT
USING (business_owner_id = auth.uid());
```

### Issue: Slow queries
**Fix**: Add database indexes
```sql
CREATE INDEX idx_bookings_owner ON bookings(business_owner_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_date ON bookings(created_at DESC);
```

---

## 📊 **Cost Estimate**

| Users | Plan | Cost/Month |
|-------|------|------------|
| 0-1K | Free | $0 |
| 1K-50K | Pro | $25 |
| 50K-100K | Pro + extras | $50-100 |
| 100K+ | Team | $599+ |

**Your current setup:**
- ✅ Free tier: Up to 50K MAU
- ✅ Upgrade to Pro when you hit limits
- ✅ Much cheaper than Encore ($99/month)

---

## 🎯 **Next Steps After Launch**

1. **Add Analytics**
   ```dart
   // Track user actions
   await supabase.from('analytics_events').insert({
     'event': 'booking_created',
     'user_id': userId,
   });
   ```

2. **Add Push Notifications**
   - Use Firebase Cloud Messaging
   - Trigger from Supabase webhooks

3. **Add Offline Support**
   - Use `sqflite` for local database
   - Sync when online

4. **Add Edge Functions** (for complex logic)
   ```bash
   supabase functions new pdf-generator
   supabase functions deploy pdf-generator
   ```

5. **Optimize Performance**
   - Add caching layer (Redis)
   - Use materialized views
   - Optimize RLS policies

---

## 🚀 **Ready to Launch?**

Follow this checklist in order, and you'll be LIVE in 2-3 hours!

**Any issues?**
- Supabase Discord: https://discord.supabase.com
- Flutter Discord: https://discord.gg/flutter

**LET'S GO! 🎉**

