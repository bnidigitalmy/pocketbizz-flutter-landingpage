# 🔧 Password Reset Email - Troubleshooting Guide

## ❌ **Masalah:**
"Ralat: Gagal menghantar email reset kata laluan"

---

## 🔍 **CHECKLIST - Kenapa Email Gagal?**

### **1. SMTP Belum Configure dalam Supabase** ⚠️ **MOST COMMON**

**Check:**
1. Supabase Dashboard → **Authentication** → **Email Templates**
2. Scroll down ke **"SMTP Settings"**
3. Check: **"Enable Custom SMTP"** - harus **ON** ✅

**Fix:**
- Jika OFF, enable dan configure:
  ```
  Host: smtp.resend.com
  Port: 465 (atau 587)
  Username: resend
  Password: [Resend API Key]
  Sender email: noreply@notifications.pocketbizz.my
  Sender name: PocketBizz
  ```

---

### **2. Resend API Key Salah atau Belum Setup**

**Check:**
1. Resend Dashboard → **API Keys**
2. Verify "Supabase Integration" key exists
3. Copy key dan paste dalam Supabase SMTP password field

**Fix:**
- Jika key tidak wujud, complete Resend integration dulu
- Go to: Resend → Settings → Integrations → Supabase
- Click "Add API key" dan "Configure SMTP integration"

---

### **3. Domain Belum Verified dalam Resend**

**Check:**
1. Resend Dashboard → **Domains**
2. Check status untuk `notifications.pocketbizz.my`
3. Verify DNS records (SPF, DKIM, DMARC) sudah setup

**Fix:**
- Jika domain belum verified, verify dulu
- Add DNS records seperti yang Resend provide
- Wait untuk verification (biasanya beberapa minit)

---

### **4. Redirect URL Tidak Match**

**Check:**
1. Supabase Dashboard → **Authentication** → **URL Configuration**
2. Verify Redirect URLs include:
   - `https://app.pocketbizz.my/reset-password`
   - Atau `https://app.pocketbizz.my/**` (wildcard)

**Fix:**
- Add redirect URL jika tidak ada
- Must match `redirectTo` parameter dalam code

---

### **5. Email Service Disabled dalam Supabase**

**Check:**
1. Supabase Dashboard → **Authentication** → **Settings**
2. Check "Enable Email Auth" - harus **ON** ✅

**Fix:**
- Enable jika OFF
- Save changes

---

## 🐛 **DEBUG STEPS**

### **Step 1: Check Console Logs**

Selepas error, check browser console (F12) untuk:
```
❌ Password reset error: [full error message]
❌ Error type: [error type]
```

**Common errors:**
- `SMTP configuration error` → SMTP belum setup
- `Invalid redirect URL` → Redirect URL tidak match
- `Email service unavailable` → Email service disabled
- `Rate limit exceeded` → Terlalu banyak requests

---

### **Step 2: Check Supabase Logs**

1. Supabase Dashboard → **Logs** → **Auth Logs**
2. Look for password reset attempts
3. Check untuk errors atau warnings

---

### **Step 3: Test dengan Different Email**

1. Try dengan email lain
2. Check jika error sama atau different
3. Jika same error → configuration issue
4. Jika different error → email-specific issue

---

## ✅ **QUICK FIXES**

### **Fix 1: Enable Default Supabase Email (Temporary)**

Jika SMTP belum ready, boleh guna default Supabase email sementara:

1. Supabase Dashboard → **Authentication** → **Email Templates** → **SMTP Settings**
2. **Disable** Custom SMTP (gunakan default)
3. Test password reset
4. Email akan datang dari "Supabase Auth" (temporary)

**Note:** Ini temporary solution. Untuk production, perlu Custom SMTP.

---

### **Fix 2: Verify Resend Integration**

1. Resend Dashboard → **Settings** → **Integrations** → **Supabase**
2. Verify:
   - ✅ Project selected: "Pocketbizz-V2-Encore"
   - ✅ Domain: "notifications.pocketbizz.my"
   - ✅ Sender name: "PocketBizz"
   - ✅ Sender email: "noreply@notifications.pocketbizz.my"
3. Click "Add API key" jika belum
4. Click "Configure SMTP integration" jika belum

---

### **Fix 3: Check Email Template**

1. Supabase Dashboard → **Authentication** → **Email Templates**
2. Check "Reset Password" template
3. Verify template ada content (bukan empty)
4. Check untuk syntax errors

---

## 📋 **MOST LIKELY CAUSE**

Berdasarkan error "Gagal menghantar email reset kata laluan", kemungkinan besar:

**🔴 SMTP Belum Configure dalam Supabase**

**Solution:**
1. Complete Resend integration (dah buat)
2. Copy API key dari Resend
3. Paste dalam Supabase SMTP settings
4. Enable Custom SMTP
5. Save

---

## 🎯 **VERIFY SETUP**

Selepas fix, test lagi:

1. Request password reset
2. Check console untuk detailed error (jika masih fail)
3. Check Supabase logs
4. Verify email received

---

## 📞 **IF STILL NOT WORKING**

1. **Check console logs** untuk full error message
2. **Check Supabase logs** untuk server-side errors
3. **Verify Resend integration** complete
4. **Test dengan default Supabase email** (temporary)

---

**Last Updated:** 2025-01-09

