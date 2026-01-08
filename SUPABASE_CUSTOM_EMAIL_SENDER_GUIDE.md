# 📧 Custom Email Sender untuk Supabase Auth

## 🎯 **Tujuan:**
Change email "from" name dari "Supabase Auth" kepada "PocketBizz"

---

## ✅ **CARA 1: Custom SMTP (RECOMMENDED)**

### **Step 1: Setup Custom SMTP dalam Supabase**

1. **Buka Supabase Dashboard:**
   - Go to: https://supabase.com/dashboard
   - Select your project

2. **Navigate to Authentication Settings:**
   - Go to: **Authentication** → **Email Templates**
   - Scroll down to **SMTP Settings**

3. **Enable Custom SMTP:**
   - Toggle "Enable Custom SMTP"
   - Fill in SMTP details:

**SMTP Configuration:**
```
Host: smtp.resend.com (or your SMTP provider)
Port: 587 (or 465 for SSL)
Username: resend (or your SMTP username)
Password: [Your Resend API Key or SMTP password]
Sender email: noreply@notifications.pocketbizz.my
Sender name: PocketBizz
```

**Recommended: Guna Resend (sama macam welcome email)**
- Resend dah ada dalam project (check `supabase/functions/send-welcome-email`)
- Professional email delivery
- Good deliverability

---

## ✅ **CARA 2: Custom Email Templates (Tanpa SMTP)**

### **Step 1: Update Email Templates dalam Supabase**

1. **Buka Supabase Dashboard:**
   - Go to: **Authentication** → **Email Templates**

2. **Select Template:**
   - Click on **"Reset Password"** template

3. **Update Template:**
   - Copy content dari `supabase_email_templates/password_reset_template.html`
   - Paste dalam Supabase email template editor
   - Save

4. **Repeat untuk templates lain:**
   - Email Confirmation
   - Magic Link
   - Email Change
   - Reauthentication

### **Step 2: Update Sender Name (Jika Available)**

**Note:** Supabase default email sender name adalah "Supabase Auth"
- Untuk change sender name, perlu guna **Custom SMTP** (Cara 1)
- Atau guna **Custom Domain** dengan email service

---

## ✅ **CARA 3: Custom Domain Email (BEST - Professional)**

### **Setup Custom Domain dengan Resend**

1. **Verify Domain dalam Resend:**
   - Go to: https://resend.com/domains
   - Add domain: `pocketbizz.my` atau `notifications.pocketbizz.my`
   - Add DNS records (SPF, DKIM, DMARC)

2. **Update Supabase SMTP:**
   - Use Resend SMTP dengan custom domain
   - Sender: `PocketBizz <noreply@notifications.pocketbizz.my>`

**Benefits:**
- ✅ Professional email address
- ✅ Better deliverability
- ✅ Brand consistency
- ✅ Custom sender name

---

## 📋 **QUICK SETUP (Resend SMTP)**

### **Step 1: Get Resend API Key**

1. Go to: https://resend.com/api-keys
2. Create new API key
3. Copy API key

### **Step 2: Configure dalam Supabase**

1. **Supabase Dashboard** → **Authentication** → **Email Templates** → **SMTP Settings**

2. **Enable Custom SMTP:**
   ```
   ✅ Enable Custom SMTP
   
   Host: smtp.resend.com
   Port: 587
   Username: resend
   Password: [Your Resend API Key]
   Sender email: noreply@notifications.pocketbizz.my
   Sender name: PocketBizz
   ```

3. **Save Changes**

### **Step 3: Update Email Templates**

1. **Copy templates dari `supabase_email_templates/`:**
   - `password_reset_template.html` → Paste dalam "Reset Password" template
   - `email_confirmation_template.html` → Paste dalam "Email Confirmation" template
   - `magic_link_template.html` → Paste dalam "Magic Link" template

2. **Save each template**

---

## 🔍 **VERIFY SETUP**

### **Test Password Reset:**

1. Request password reset
2. Check email
3. **Verify:**
   - ✅ Sender name: "PocketBizz" (bukan "Supabase Auth")
   - ✅ Sender email: `noreply@notifications.pocketbizz.my`
   - ✅ Email content: Custom template dengan PocketBizz branding

---

## 📝 **TEMPLATES LOCATION**

Templates sudah ready dalam:
- `supabase_email_templates/password_reset_template.html`
- `supabase_email_templates/email_confirmation_template.html`
- `supabase_email_templates/magic_link_template.html`
- `supabase_email_templates/email_change_template.html`
- `supabase_email_templates/reauthentication_template.html`

**Bahasa:**
- Malay versions: `*_template.html`
- English versions: `*_template_english.html`

---

## ⚠️ **IMPORTANT NOTES**

1. **Custom SMTP Required:**
   - Untuk change sender name, **MESTI** guna Custom SMTP
   - Default Supabase email sender adalah "Supabase Auth" (tidak boleh change tanpa SMTP)

2. **Resend Recommended:**
   - Already integrated dalam project
   - Professional email service
   - Good deliverability rates

3. **Domain Verification:**
   - Untuk custom domain email, perlu verify domain dalam Resend
   - Add DNS records (SPF, DKIM, DMARC)

---

## 🎯 **RECOMMENDED APPROACH**

**Best Practice:**
1. ✅ Setup Resend SMTP dalam Supabase
2. ✅ Use custom domain: `noreply@notifications.pocketbizz.my`
3. ✅ Sender name: "PocketBizz"
4. ✅ Copy custom templates dari `supabase_email_templates/`

**Result:**
- Professional email sender
- Brand consistency
- Better user experience
- Higher email deliverability

---

**Last Updated:** 2025-01-09

