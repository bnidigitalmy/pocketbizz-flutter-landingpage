# 🔧 Password Reset Email - SMTP Troubleshooting Guide

## ❌ **Error yang Dihadapi:**
```
AuthRetryableFetchException(message: {"code":"unexpected_failure", "message":"Error sending recovery email"}, statusCode: 500)
```

## 🔍 **Punca Masalah (500 Error):**

Error 500 dari Supabase bermaksud masalah di server-side. Kemungkinan:

1. **Redirect URL tidak whitelisted** di Supabase
2. **SMTP integration belum fully active** (perlu beberapa minit untuk sync)
3. **Domain verification** di Resend belum complete
4. **SMTP credentials** tidak betul atau expired

---

## ✅ **Step-by-Step Fix:**

### **Step 1: Verify Redirect URL di Supabase**

1. **Buka Supabase Dashboard:**
   - Go to: https://app.supabase.com
   - Select project anda

2. **Navigate ke Authentication Settings:**
   - Go to: **Authentication** → **URL Configuration**

3. **Check Redirect URLs:**
   - Pastikan ada: `https://app.pocketbizz.my/**` (dengan `/**` untuk allow semua paths)
   - Atau specific: `https://app.pocketbizz.my/reset-password`
   - **JANGAN LUPA:** Tambah juga untuk localhost development:
     - `http://localhost:*/**` (untuk Flutter web dev server)

4. **Check Site URL:**
   - Pastikan Site URL set ke: `https://app.pocketbizz.my`
   - Atau `https://pocketbizz-app.web.app` (Firebase hosting)

5. **Save Changes** ✅

---

### **Step 2: Verify SMTP Integration Status**

1. **Go to:** Authentication → Email Templates
2. **Check SMTP Status:**
   - Look for "SMTP Integration" atau "Custom SMTP" section
   - Status harus menunjukkan: **"Active"** atau **"Connected"**
   - Jika masih "Pending" atau "Not Configured", tunggu 5-10 minit untuk sync

3. **Test SMTP Connection:**
   - Supabase ada button "Test SMTP" atau "Send Test Email"
   - Cuba send test email untuk verify SMTP working

---

### **Step 3: Verify Resend Domain & API Key**

1. **Check Resend Dashboard:**
   - Go to: https://resend.com/domains
   - Verify domain `notifications.pocketbizz.my` status:
     - ✅ **Verified** (green checkmark)
     - ✅ **DNS records** (SPF, DKIM, DMARC) semua pass

2. **Check API Key:**
   - Go to: https://resend.com/api-keys
   - Pastikan API key yang digunakan di Supabase masih **active**
   - Pastikan API key ada permission untuk send emails

3. **Check Domain Status:**
   - Domain harus **fully verified** sebelum boleh send emails
   - Jika masih "Pending Verification", tunggu DNS propagation (boleh ambil 24-48 jam)

---

### **Step 4: Verify SMTP Credentials di Supabase**

1. **Go to:** Authentication → Email Templates → SMTP Settings
2. **Verify semua fields:**
   ```
   Sender name: PocketBizz
   Sender email: noreply@notifications.pocketbizz.my
   Host: smtp.resend.com
   Port: 465 (atau 587 untuk TLS)
   User: resend
   Password: [API key dari Resend]
   ```

3. **Important Notes:**
   - **Port 465** = SSL/TLS (recommended)
   - **Port 587** = STARTTLS (alternative)
   - **Password** = Resend API key (bukan account password)

---

### **Step 5: Check Supabase Logs**

1. **Go to:** Supabase Dashboard → Logs → Auth Logs
2. **Look for:**
   - Error messages related to email sending
   - SMTP connection errors
   - Rate limiting errors

3. **Common Errors:**
   - `SMTP connection failed` → Check credentials
   - `Domain not verified` → Verify domain di Resend
   - `Rate limit exceeded` → Wait before retry
   - `Invalid redirect URL` → Add URL to whitelist

---

## 🧪 **Testing Steps:**

### **Test 1: Verify Redirect URL**
```bash
# Test jika URL boleh diakses
curl -I https://app.pocketbizz.my/reset-password
```

### **Test 2: Send Test Email dari Supabase**
1. Go to: Authentication → Email Templates
2. Click "Send Test Email" atau "Test SMTP"
3. Check jika email sampai

### **Test 3: Check Browser Console**
- Open Chrome DevTools → Console
- Look for detailed error messages
- Check Network tab untuk failed requests

---

## 🔥 **Quick Fix Checklist:**

- [ ] Redirect URL `https://app.pocketbizz.my/**` added di Supabase
- [ ] Site URL set correctly di Supabase
- [ ] SMTP integration status = "Active" atau "Connected"
- [ ] Resend domain `notifications.pocketbizz.my` fully verified
- [ ] Resend API key active dan correct
- [ ] SMTP credentials correct (host, port, user, password)
- [ ] Wait 5-10 minit untuk SMTP sync (jika baru configure)
- [ ] Test send email dari Supabase dashboard

---

## 🆘 **Jika Masih Error:**

### **Option 1: Use Supabase Default Email (Temporary)**
1. **Disable Custom SMTP** di Supabase
2. **Use Supabase default email** (from `noreply@mail.app.supabase.io`)
3. **Test password reset** untuk confirm flow working
4. **Re-enable Custom SMTP** selepas domain verified

### **Option 2: Check Resend API Limits**
1. Go to: https://resend.com/dashboard
2. Check **API usage** dan **rate limits**
3. Verify tidak exceed limits

### **Option 3: Contact Support**
- **Supabase Support:** support@supabase.com
- **Resend Support:** support@resend.com
- Provide error details dan configuration screenshots

---

## 📝 **Notes:**

1. **SMTP Sync Time:**
   - Supabase boleh ambil 5-10 minit untuk fully sync dengan SMTP settings baru
   - Jika baru configure, **tunggu beberapa minit** sebelum test

2. **Domain Verification:**
   - DNS records (SPF, DKIM, DMARC) mesti semua pass
   - Boleh ambil 24-48 jam untuk full verification
   - Check Resend dashboard untuk status

3. **Redirect URL Format:**
   - Use `/**` untuk allow semua paths (recommended)
   - Atau specific path: `/reset-password`
   - **JANGAN LUPA:** Include localhost untuk development

4. **Error 500 vs 400:**
   - **500** = Server error (SMTP/configuration issue)
   - **400** = Client error (invalid email, rate limit, etc.)

---

## ✅ **Success Indicators:**

- ✅ Email sampai dalam inbox (check spam juga)
- ✅ Link redirect ke `https://app.pocketbizz.my/reset-password`
- ✅ No errors di browser console
- ✅ Supabase logs show "Email sent successfully"

---

**Last Updated:** 2025-01-XX

