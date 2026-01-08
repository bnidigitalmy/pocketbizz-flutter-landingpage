# ✅ Supabase + Resend Integration - Complete Setup

## 🎯 **Status:**
Integration sudah setup dalam Resend. Sekarang perlu apply ke Supabase.

---

## 📋 **STEP-BY-STEP SETUP**

### **Step 1: Complete Resend Integration** ✅ (Dah buat)

Dari screenshot, anda sudah:
- ✅ Select project: "Pocketbizz-V2-Encore"
- ✅ Domain: "notifications.pocketbizz.my"
- ✅ Sender name: "PocketBizz"
- ✅ Sender email: "noreply@notifications.pocketbizz.my"
- ✅ SMTP config ready

**Next:**
1. Click **"Add API key"** button
2. Click **"Configure SMTP integration"** button
3. Copy the API key yang auto-generated

---

### **Step 2: Apply ke Supabase Dashboard**

1. **Buka Supabase Dashboard:**
   - Go to: https://supabase.com/dashboard
   - Select project: "Pocketbizz-V2-Encore"

2. **Navigate to SMTP Settings:**
   - Go to: **Authentication** → **Email Templates**
   - Scroll down to **"SMTP Settings"**
   - Click **"Enable Custom SMTP"**

3. **Enter SMTP Configuration:**
   ```
   ✅ Enable Custom SMTP
   
   Host: smtp.resend.com
   Port: 465 (or 587 - check Resend docs)
   Username: resend
   Password: [Paste API key dari Resend - "Supabase Integration" key]
   Sender email: noreply@notifications.pocketbizz.my
   Sender name: PocketBizz
   ```

4. **Save Changes**

---

### **Step 3: Update Email Templates**

1. **Go to Email Templates:**
   - Supabase Dashboard → **Authentication** → **Email Templates**

2. **Update Each Template:**

   **a) Reset Password:**
   - Click on **"Reset Password"** template
   - Copy content dari: `supabase_email_templates/password_reset_template.html`
   - Paste & Save

   **b) Email Confirmation:**
   - Click on **"Confirm signup"** template
   - Copy content dari: `supabase_email_templates/email_confirmation_template.html`
   - Paste & Save

   **c) Magic Link:**
   - Click on **"Magic Link"** template
   - Copy content dari: `supabase_email_templates/magic_link_template.html`
   - Paste & Save

   **d) Email Change:**
   - Click on **"Change Email Address"** template
   - Copy content dari: `supabase_email_templates/email_change_template.html`
   - Paste & Save

   **e) Reauthentication:**
   - Click on **"Reauthentication"** template
   - Copy content dari: `supabase_email_templates/reauthentication_template.html`
   - Paste & Save

---

## ✅ **VERIFY SETUP**

### **Test Password Reset:**

1. Request password reset dari app
2. Check email inbox
3. **Verify:**
   - ✅ **From:** "PocketBizz" (bukan "Supabase Auth")
   - ✅ **Email:** noreply@notifications.pocketbizz.my
   - ✅ **Content:** Custom template dengan PocketBizz branding
   - ✅ **Logo:** PocketBizz logo visible

---

## 🎯 **BENEFITS OF INTEGRATION**

### **✅ Automatic Setup:**
- No manual SMTP configuration needed
- API key auto-generated
- Domain auto-verified

### **✅ Better Management:**
- Centralized dalam Resend dashboard
- Easy to update sender name/email
- Better email analytics

### **✅ Professional:**
- Custom domain email
- Branded sender name
- Better deliverability

---

## 📝 **IMPORTANT NOTES**

1. **API Key:**
   - Resend akan auto-create API key bernama "Supabase Integration"
   - Copy key ini untuk paste dalam Supabase SMTP password field

2. **Port:**
   - Check Resend docs untuk correct port
   - Usually: 465 (SSL) or 587 (TLS)
   - Screenshot shows 465

3. **Domain Verification:**
   - Pastikan domain `notifications.pocketbizz.my` sudah verified dalam Resend
   - Check: Resend Dashboard → Domains

4. **Sender Name:**
   - Sender name "PocketBizz" akan muncul dalam email client
   - User akan nampak: "PocketBizz <noreply@notifications.pocketbizz.my>"

---

## 🔍 **TROUBLESHOOTING**

### **If emails not sending:**

1. **Check API Key:**
   - Verify API key dalam Supabase SMTP settings
   - Make sure it's the "Supabase Integration" key from Resend

2. **Check Domain:**
   - Verify domain dalam Resend Dashboard → Domains
   - Make sure DNS records (SPF, DKIM, DMARC) are set

3. **Check Port:**
   - Try port 587 if 465 doesn't work
   - Or vice versa

4. **Check Supabase Logs:**
   - Go to Supabase Dashboard → Logs
   - Look for email sending errors

---

## 📚 **RESOURCES**

- Resend Integration: https://resend.com/integrations/supabase
- Supabase SMTP Setup: https://supabase.com/docs/guides/auth/auth-smtp
- Email Templates: `supabase_email_templates/` folder

---

**Last Updated:** 2025-01-09

