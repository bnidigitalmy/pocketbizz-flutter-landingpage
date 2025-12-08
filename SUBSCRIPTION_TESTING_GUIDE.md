# Subscription System Testing Guide

## 📍 **CARA REGISTER & TEST**

### **1. Register New User (Auto-Trial Start)**

#### **Langkah:**
1. **Buka app** - App akan show Login Page
2. **Click "Don't have an account? Sign Up"** button (di bawah password field)
3. **Isi maklumat:**
   - Email: `test@example.com` (atau email baru)
   - Password: Minimum 6 characters
4. **Click "Sign Up"**
5. **Trial akan auto-start** - Success message akan show: "Account created! Free 7-day trial started. You can now sign in."

#### **Apa yang berlaku:**
- ✅ User record created dalam `users` table
- ✅ Early adopter check (first 100 users dapat RM 29/month)
- ✅ Trial subscription created (7 days free)
- ✅ Status: `trial`, expires in 7 days

---

### **2. Test Consignment Features (Full Access - Trial)**

#### **Langkah:**
1. **Sign in** dengan account yang baru register
2. **Navigate ke Consignment features:**
   - **Tuntutan**: Sidebar → KEWANGAN → Tuntutan
   - **Vendor**: Sidebar → PENGEDARAN & RAKAN KONGSI → Vendor
   - **Cipta Tuntutan**: Tuntutan page → Click "Cipta Tuntutan" button

#### **Expected Result:**
- ✅ **Full access** - Boleh create claims, manage vendors, etc.
- ✅ **No upgrade prompts** - Trial users dapat full access
- ✅ **All features unlocked** - Consignment system fully accessible

---

### **3. Test Dashboard Alert (Trial Expiring Soon)**

#### **Langkah:**
1. **Sign in** dengan trial account
2. **Check Dashboard** - Alert akan muncul jika trial < 7 days
3. **Alert akan show:**
   - "Trial Hampir Tamat!"
   - Days remaining
   - "Upgrade" button

#### **Expected Result:**
- ✅ **Alert banner** muncul di top of dashboard
- ✅ **Shows days remaining** (e.g., "Trial percuma anda akan tamat dalam 5 hari")
- ✅ **"Upgrade" button** yang navigate ke subscription page

---

### **4. Test Subscription Page**

#### **Langkah:**
1. **Navigate ke Subscription:**
   - Sidebar → KEWANGAN → Langganan
   - Atau click "Upgrade" button dari dashboard alert
2. **Check subscription status:**
   - Current plan: "Free Trial"
   - Days remaining dengan progress bar
   - Plan limits (Products, Stock, Transactions)

#### **Expected Result:**
- ✅ **Status badge**: "Trial" (blue)
- ✅ **Progress bar** showing days remaining
- ✅ **Package selection** available (1, 3, 6, 12 months)
- ✅ **Pricing** shows (RM 29 jika early adopter, RM 39 standard)

---

### **5. Test Payment Flow (bcl.my)**

#### **Langkah:**
1. **Go to Subscription page**
2. **Click package button** (e.g., "1 Bulan")
3. **Alert dialog akan muncul:**
   - Shows user email
   - Reminder: "Gunakan email yang sama semasa isi borang pembayaran"
4. **Click "Teruskan ke Pembayaran"**
5. **Redirect ke bcl.my** payment form

#### **Expected Result:**
- ✅ **Alert dialog** dengan email reminder
- ✅ **Redirect ke bcl.my** form URL
- ✅ **Different URLs** untuk setiap duration:
   - 1 Bulan: `https://bnidigital.bcl.my/form/1-bulan`
   - 3 Bulan: `https://bnidigital.bcl.my/form/3-bulan`
   - 6 Bulan: `https://bnidigital.bcl.my/form/6-bulan`
   - 12 Bulan: `https://bnidigital.bcl.my/form/12-bulan`

---

### **6. Test Feature Gates (After Trial Expires)**

#### **Untuk test expired subscription:**
1. **Manual update** dalam database:
   ```sql
   UPDATE subscriptions 
   SET status = 'expired', 
       trial_ends_at = NOW() - INTERVAL '1 day',
       expires_at = NOW() - INTERVAL '1 day'
   WHERE user_id = 'YOUR_USER_ID';
   ```

2. **Refresh app** dan try access consignment features

#### **Expected Result:**
- ❌ **Upgrade prompt** muncul instead of feature
- ✅ **Shows feature name**: "Sistem Konsinyemen"
- ✅ **"Lihat Pakej Langganan" button**
- ✅ **"Kembali" button** untuk go back

---

## 🧪 **Testing Checklist**

### **Registration & Trial**
- [ ] Register new user
- [ ] Check trial auto-started
- [ ] Check early adopter status (first 100 users)
- [ ] Verify trial duration (7 days)

### **Consignment Features (Trial)**
- [ ] Access Claims page - Full access ✅
- [ ] Access Vendors page - Full access ✅
- [ ] Create new claim - Full access ✅
- [ ] No upgrade prompts shown

### **Dashboard Alerts**
- [ ] Alert shows when trial < 7 days
- [ ] Days remaining displayed correctly
- [ ] "Upgrade" button works
- [ ] Alert disappears after upgrade

### **Subscription Page**
- [ ] Current plan displayed
- [ ] Status badge correct (Trial/Active)
- [ ] Progress bar shows days remaining
- [ ] Plan limits displayed
- [ ] Package selection shows correct pricing
- [ ] Early adopter pricing applied (if applicable)

### **Payment Flow**
- [ ] Payment dialog shows email reminder
- [ ] Redirect to bcl.my works
- [ ] Correct URL for each duration

### **Feature Gates**
- [ ] Expired users see upgrade prompt
- [ ] Upgrade prompt shows feature name
- [ ] Navigation to subscription page works

---

## 📝 **Quick Test Commands**

### **Check Subscription Status (Supabase SQL)**
```sql
SELECT 
  s.id,
  s.status,
  s.trial_ends_at,
  s.expires_at,
  s.is_early_adopter,
  s.price_per_month,
  u.email
FROM subscriptions s
JOIN auth.users u ON s.user_id = u.id
WHERE u.email = 'test@example.com'
ORDER BY s.created_at DESC
LIMIT 1;
```

### **Check Early Adopter Count**
```sql
SELECT COUNT(*) as early_adopter_count
FROM early_adopters
WHERE is_active = TRUE;
```

### **Manually Expire Trial (For Testing)**
```sql
UPDATE subscriptions 
SET 
  status = 'expired',
  trial_ends_at = NOW() - INTERVAL '1 day',
  expires_at = NOW() - INTERVAL '1 day'
WHERE user_id = 'YOUR_USER_ID';
```

---

## 🎯 **Test Scenarios**

### **Scenario 1: New User Registration**
1. Register → Trial starts → Full access
2. **Expected**: Trial active, all features accessible

### **Scenario 2: Early Adopter (First 100)**
1. Register within first 100 users
2. **Expected**: Early adopter status = true, pricing = RM 29/month

### **Scenario 3: Standard User (After 100)**
1. Register after 100 users
2. **Expected**: Early adopter status = false, pricing = RM 39/month

### **Scenario 4: Trial Expiring Soon**
1. Trial < 7 days remaining
2. **Expected**: Dashboard alert shows, upgrade prompts visible

### **Scenario 5: Expired Trial**
1. Trial expired
2. **Expected**: Feature gates active, upgrade prompts everywhere

---

## 🔗 **Navigation Paths**

### **To Register:**
- App opens → Login Page → Click "Don't have an account? Sign Up"

### **To Subscription Page:**
- Sidebar → KEWANGAN → Langganan
- Dashboard alert → Click "Upgrade" button
- Feature gate → Click "Lihat Pakej Langganan"

### **To Consignment Features:**
- Sidebar → KEWANGAN → Tuntutan
- Sidebar → PENGEDARAN & RAKAN KONGSI → Vendor

---

## ✅ **Ready to Test!**

Semua features dah siap. Boleh start testing sekarang! 🚀


