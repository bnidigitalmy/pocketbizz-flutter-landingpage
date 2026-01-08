# ✅ SMTP Fix Checklist - PocketBizz

## 🎯 **Goal:**
Enable Custom SMTP dengan Resend supaya email dari `noreply@notifications.pocketbizz.my` boleh jalan.

---

## 📋 **Step-by-Step Checklist:**

### **Step 1: Verify Resend Domain** ✅

1. **Go to:** https://resend.com/domains
2. **Check domain:** `notifications.pocketbizz.my`
3. **Verify status:**
   - [ ] Domain status = **"Verified"** (green checkmark)
   - [ ] SPF record = ✅ Pass
   - [ ] DKIM record = ✅ Pass
   - [ ] DMARC record = ✅ Pass (optional but recommended)

4. **If not verified:**
   - Check DNS records di domain provider
   - Wait for DNS propagation (boleh ambil 24-48 jam)
   - Verify semua records match Resend requirements

---

### **Step 2: Verify Resend API Key** ✅

1. **Go to:** https://resend.com/api-keys
2. **Check API key yang digunakan di Supabase:**
   - [ ] API key status = **"Active"**
   - [ ] API key ada permission untuk **send emails**
   - [ ] Copy API key untuk Step 3

---

### **Step 3: Configure SMTP di Supabase** ✅

1. **Go to:** Supabase Dashboard → Authentication → Email Templates
2. **Navigate to:** SMTP Settings atau Custom SMTP
3. **Fill in details:**
   ```
   Sender name: PocketBizz
   Sender email: noreply@notifications.pocketbizz.my
   Host: smtp.resend.com
   Port: 465 (SSL/TLS) atau 587 (STARTTLS)
   User: resend
   Password: [Resend API Key dari Step 2]
   ```

4. **Important:**
   - [ ] **Password** = Resend API Key (bukan account password)
   - [ ] **Port 465** recommended untuk SSL/TLS
   - [ ] **Sender email** mesti match domain yang verified di Resend

5. **Click:** "Configure SMTP" atau "Save"

---

### **Step 4: Whitelist Redirect URL di Supabase** ✅

1. **Go to:** Supabase Dashboard → Authentication → URL Configuration
2. **Check Redirect URLs:**
   - [ ] Add: `https://app.pocketbizz.my/**` (dengan `/**` untuk allow semua paths)
   - [ ] Atau specific: `https://app.pocketbizz.my/reset-password`
   - [ ] Keep localhost untuk development: `http://localhost:*/**`

3. **Check Site URL:**
   - [ ] Set to: `https://app.pocketbizz.my` atau Firebase hosting URL

4. **Save changes**

---

### **Step 5: Test SMTP Connection** ✅

1. **Go to:** Supabase Dashboard → Authentication → Email Templates
2. **Look for:** "Test SMTP" atau "Send Test Email" button
3. **Send test email:**
   - [ ] Test email sampai dalam inbox
   - [ ] Check spam folder juga
   - [ ] Verify sender = `noreply@notifications.pocketbizz.my`

4. **If test email fails:**
   - Check Supabase logs untuk error details
   - Verify SMTP credentials again
   - Check Resend dashboard untuk API usage/errors

---

### **Step 6: Wait for Sync** ⏳

1. **After configuring SMTP:**
   - [ ] Wait **5-10 minit** untuk Supabase sync dengan SMTP settings
   - [ ] Check SMTP status = **"Active"** atau **"Connected"**

2. **If status still "Pending":**
   - Wait longer (boleh ambil up to 15 minit)
   - Try disable and re-enable SMTP
   - Check Supabase status page untuk any issues

---

### **Step 7: Test dari App** 🧪

1. **Open app:** Forgot Password page
2. **Enter email:** Test email address
3. **Click:** "Hantar Link Reset"
4. **Expected result:**
   - [ ] No error (success message)
   - [ ] Email sampai dalam inbox
   - [ ] Email from = `noreply@notifications.pocketbizz.my`
   - [ ] Link redirect ke `https://app.pocketbizz.my/reset-password`

5. **If still error 500:**
   - Check browser console untuk detailed error
   - Verify all steps above completed
   - Check Supabase logs → Auth Logs untuk server-side errors

---

## 🔍 **Troubleshooting:**

### **Error: "Domain not verified"**
- **Fix:** Verify domain di Resend dashboard
- **Check:** DNS records (SPF, DKIM) semua pass
- **Wait:** DNS propagation (24-48 jam)

### **Error: "SMTP connection failed"**
- **Fix:** Check SMTP credentials (host, port, user, password)
- **Verify:** Password = Resend API Key (bukan account password)
- **Try:** Port 587 instead of 465 (or vice versa)

### **Error: "Invalid redirect URL"**
- **Fix:** Add `https://app.pocketbizz.my/**` to Supabase redirect URLs
- **Verify:** Site URL juga set correctly

### **Error: "Rate limit exceeded"**
- **Fix:** Check Resend API usage limits
- **Wait:** Reset period (usually 1 hour)
- **Upgrade:** Resend plan if needed

### **Error: 500 "Error sending recovery email"**
- **Possible causes:**
  1. SMTP belum fully sync (wait 5-10 minit)
  2. Domain belum verified (check Resend)
  3. Redirect URL tidak whitelisted (check Supabase)
  4. SMTP credentials salah (verify again)

---

## ✅ **Success Indicators:**

- [ ] SMTP status = "Active" di Supabase
- [ ] Test email dari Supabase dashboard sampai
- [ ] Password reset email dari app sampai
- [ ] Email from = `noreply@notifications.pocketbizz.my`
- [ ] No errors di browser console
- [ ] Link redirect berfungsi dengan betul

---

## 📝 **Notes:**

1. **DNS Propagation:**
   - Boleh ambil 24-48 jam untuk full verification
   - Check Resend dashboard untuk real-time status

2. **SMTP Sync:**
   - Supabase boleh ambil 5-15 minit untuk sync
   - Be patient dan check status periodically

3. **Fallback:**
   - Jika SMTP masih error, boleh guna Supabase default email temporarily
   - User masih boleh reset password, cuma sender = `noreply@mail.app.supabase.io`

4. **Testing:**
   - Always test dari Supabase dashboard first
   - Then test dari app untuk full flow

---

**Last Updated:** 2025-01-09

