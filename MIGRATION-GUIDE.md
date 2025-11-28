# PocketBizz Migration: Encore → Supabase

## Phase 1: Supabase Project Setup

### 1.1 Create Supabase Project

1. Go to https://supabase.com/dashboard
2. Click **"New Project"**
3. Fill in:
   - **Name**: pocketbizz-v2
   - **Database Password**: (Generate strong password - SAVE IT!)
   - **Region**: Southeast Asia (Singapore) - closest to Malaysia
   - **Pricing Plan**: Free (upgrade to Pro when needed)
4. Click **"Create new project"**
5. Wait 2-3 minutes for provisioning

### 1.2 Get Project Credentials

Once project is ready:

1. Go to **Settings** → **API**
2. Copy these values:
   ```
   Project URL: https://xxxxx.supabase.co
   anon/public key: eyJhbGc...
   service_role key: eyJhbGc... (keep secret!)
   ```

3. Save to `.env.local`:
   ```env
   SUPABASE_URL=https://xxxxx.supabase.co
   SUPABASE_ANON_KEY=eyJhbGc...
   SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...
   ```

---

## Phase 2: Database Migration

### 2.1 Apply Database Schema

You already have `db/schema.sql` ready!

**Option A: Via Supabase Dashboard (Easiest)**

1. Open Supabase Dashboard
2. Go to **SQL Editor**
3. Click **"New query"**
4. Copy contents from `db/schema.sql`
5. Click **"Run"**
6. Verify: Go to **Database** → **Tables** (should see all tables)

**Option B: Via Supabase CLI**

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link project
supabase link --project-ref YOUR_PROJECT_REF

# Run migration
supabase db push
```

### 2.2 Verify RLS Policies

1. Go to **Authentication** → **Policies**
2. Check each table has policies enabled
3. Test: Try to query tables (should return empty, not error)

---

## Phase 3: Flutter App Update

### 3.1 Install Supabase Flutter SDK

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.3.4
```

```bash
flutter pub get
```

### 3.2 Initialize Supabase

```dart
// lib/main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  runApp(MyApp());
}

// Global accessor
final supabase = Supabase.instance.client;
```

### 3.3 Update API Calls

**Before (Encore):**
```dart
final response = await http.post(
  Uri.parse('http://localhost:4000/bookings/create'),
  body: jsonEncode(data),
);
```

**After (Supabase):**
```dart
final booking = await supabase
  .from('bookings')
  .insert({
    'customer_name': customerName,
    'total_amount': totalAmount,
    // ... other fields
  })
  .select()
  .single();
```

---

## Phase 4: Edge Functions (For Complex Operations)

### 4.1 Setup Edge Functions

```bash
# Init Supabase in project
supabase init

# Create functions directory
mkdir -p supabase/functions
```

### 4.2 Create Edge Functions

Example: Production Planning
```bash
supabase functions new production-plan
```

File: `supabase/functions/production-plan/index.ts`
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { productId, quantity } = await req.json()
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Complex business logic here
    // ... fetch recipe, check inventory, calculate costs
    
    return new Response(
      JSON.stringify({ success: true, data: result }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    )
  }
})
```

### 4.3 Deploy Edge Functions

```bash
# Deploy specific function
supabase functions deploy production-plan

# Deploy all functions
supabase functions deploy
```

### 4.4 Call Edge Functions from Flutter

```dart
final response = await supabase.functions.invoke(
  'production-plan',
  body: {
    'productId': productId,
    'quantity': quantity,
  },
);

final data = response.data;
```

---

## Phase 5: Authentication

### 5.1 Setup Auth in Supabase

1. Go to **Authentication** → **Providers**
2. Enable **Email** (already enabled by default)
3. Optional: Enable **Google**, **Apple**, etc.

### 5.2 Update Flutter Auth

```dart
// Sign Up
final response = await supabase.auth.signUp(
  email: email,
  password: password,
);

// Sign In
final response = await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);

// Sign Out
await supabase.auth.signOut();

// Get current user
final user = supabase.auth.currentUser;

// Listen to auth changes
supabase.auth.onAuthStateChange.listen((data) {
  final event = data.event;
  final user = data.session?.user;
});
```

---

## Phase 6: Testing

### 6.1 Local Testing Checklist

- [ ] User can sign up
- [ ] User can sign in
- [ ] User can create booking
- [ ] User can list bookings
- [ ] User can view booking details
- [ ] User can update booking
- [ ] User can delete booking
- [ ] RLS policies work (user only sees own data)

### 6.2 Production Testing

- [ ] Deploy Flutter app to TestFlight/Play Console Internal Testing
- [ ] Test with real devices
- [ ] Check Supabase logs for errors
- [ ] Monitor database performance

---

## Phase 7: Go Live! 🚀

### 7.1 Deploy Flutter App

**Android:**
```bash
flutter build appbundle
# Upload to Play Console
```

**iOS:**
```bash
flutter build ipa
# Upload to App Store Connect
```

### 7.2 Monitor & Optimize

1. **Supabase Dashboard**:
   - Monitor API usage
   - Check database size
   - Review logs

2. **Performance**:
   - Add database indexes for slow queries
   - Optimize RLS policies
   - Cache frequently accessed data

3. **Costs**:
   - Stay on Free tier until 50K MAU
   - Upgrade to Pro ($25/mo) when needed

---

## Quick Reference: Key Differences

| Operation | Encore | Supabase |
|-----------|--------|----------|
| **Create** | `POST /bookings/create` | `supabase.from('bookings').insert()` |
| **Read** | `GET /bookings/list` | `supabase.from('bookings').select()` |
| **Update** | `PUT /bookings/:id` | `supabase.from('bookings').update().eq('id', id)` |
| **Delete** | `DELETE /bookings/:id` | `supabase.from('bookings').delete().eq('id', id)` |
| **Auth** | Custom JWT | `supabase.auth.signInWithPassword()` |

---

## Troubleshooting

### Issue: "Row Level Security" error
**Solution**: Make sure user is authenticated and RLS policies are correct

### Issue: "JWT expired"
**Solution**: Supabase auto-refreshes tokens, ensure you're using latest SDK

### Issue: "permission denied for table"
**Solution**: Check RLS policies and ensure `business_owner_id = auth.uid()`

---

## Migration Complete! 🎉

Your app is now:
- ✅ **Live** on Supabase
- ✅ **Scalable** to 10K+ users
- ✅ **Secure** with RLS
- ✅ **Cost-effective** (~$0-25/month)
- ✅ **Maintainable** with clear patterns

**Next Steps:**
1. Monitor usage in Supabase Dashboard
2. Add Edge Functions for complex operations as needed
3. Optimize based on real user feedback
4. Scale up when you hit limits

---

**Need help?**
- Supabase Discord: https://discord.supabase.com
- Supabase Docs: https://supabase.com/docs
- Flutter Supabase: https://supabase.com/docs/guides/getting-started/tutorials/with-flutter

