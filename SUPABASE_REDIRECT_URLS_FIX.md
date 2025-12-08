# 🔧 Fix Supabase Redirect URLs (Remove Vercel)

## ❌ **Masalah:**
Supabase redirect URLs masih point ke Vercel:
- `pocketbizz-bnidigitalmys-projects.vercel.app`
- Email confirmation links point ke Vercel (404 error)

## ✅ **Solution: Update Supabase Redirect URLs**

### **Step 1: Update Supabase Dashboard**

1. **Buka Supabase Dashboard:**
   - Go to: https://supabase.com/dashboard
   - Select your project

2. **Navigate to Authentication Settings:**
   - Go to: **Authentication** → **URL Configuration**

3. **Update Site URL:**
   - **Current:** `https://pocketbizz-bnidigitalmys-projects.vercel.app`
   - **Change to:** `https://pocketbizz-app.web.app` (atau Firebase hosting URL anda)

4. **Update Redirect URLs:**
   - **Remove:**
     - `https://pocketbizz-bnidigitalmys-projects.vercel.app/**`
     - `https://pocketbizz.vercel.app/**`
     - `https://pocketbizz-*.vercel.app/**`
   
   - **Add:**
     - `https://pocketbizz-app.web.app/**`
     - `https://pocketbizz-app.firebaseapp.com/**`
     - `http://localhost:3000/**` (untuk local development)
     - `http://localhost:61660/**` (untuk Flutter web dev)

5. **Save Changes**

---

### **Step 2: Update Email Templates (Optional)**

1. **Go to:** Authentication → Email Templates
2. **Update Confirmation Email:**
   - Change redirect URL dari Vercel ke Firebase hosting
   - Template variable: `{{ .SiteURL }}` akan auto-use Site URL yang dah di-set

---

### **Step 3: Handle Expired OTP Links**

Add error handling untuk expired OTP links dalam app:

**File:** `lib/features/auth/presentation/login_page.dart`

```dart
// Handle error from URL parameters
void _handleAuthError() {
  final uri = Uri.base;
  final error = uri.queryParameters['error'];
  final errorCode = uri.queryParameters['error_code'];
  final errorDescription = uri.queryParameters['error_description'];

  if (error != null && mounted) {
    String message = 'Authentication error occurred.';
    
    if (errorCode == 'otp_expired') {
      message = 'Email confirmation link has expired. Please request a new confirmation email.';
    } else if (errorDescription != null) {
      message = Uri.decodeComponent(errorDescription);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Resend',
          onPressed: () {
            // TODO: Implement resend confirmation email
          },
        ),
      ),
    );
  }
}
```

---

### **Step 4: Test**

1. **Register new user:**
   - Email confirmation link sepatutnya point ke Firebase hosting
   - Click link - should redirect to app, not 404

2. **Check expired link:**
   - Try old Vercel link - should show proper error message
   - Request new confirmation email

---

## 📋 **Checklist:**

- [ ] Update Site URL dalam Supabase Dashboard
- [ ] Remove Vercel URLs dari Redirect URLs
- [ ] Add Firebase hosting URLs
- [ ] Test email confirmation link
- [ ] Test expired link handling
- [ ] Update email templates (optional)

---

## 🔗 **Current URLs to Update:**

### **Remove:**
- `https://pocketbizz-bnidigitalmys-projects.vercel.app/**`
- `https://pocketbizz.vercel.app/**`
- `https://pocketbizz-*.vercel.app/**`

### **Add:**
- `https://pocketbizz-app.web.app/**` (Firebase hosting)
- `https://pocketbizz-app.firebaseapp.com/**` (Firebase hosting alt)
- `http://localhost:3000/**` (Local dev)
- `http://localhost:61660/**` (Flutter web dev)

---

## ⚠️ **Important:**

Selepas update Supabase redirect URLs:
- **Old Vercel links akan tidak berfungsi** (expected)
- **New email confirmation links akan point ke Firebase hosting**
- **Users perlu request new confirmation email jika old link expired**

---

## 🎯 **Quick Fix:**

1. **Supabase Dashboard** → Authentication → URL Configuration
2. **Site URL:** `https://pocketbizz-app.web.app`
3. **Redirect URLs:** Remove semua Vercel URLs, add Firebase URLs
4. **Save** ✅

Done! 🚀


