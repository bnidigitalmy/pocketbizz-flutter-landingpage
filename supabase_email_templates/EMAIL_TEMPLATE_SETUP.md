# 📧 PocketBizz Email Template Setup Guide

This guide shows how to customize Supabase email templates with PocketBizz branding.

---

## 🎨 Email Confirmation Template

### **What's Included:**

✅ Professional PocketBizz branding  
✅ Gradient header dengan logo  
✅ Clear call-to-action button  
✅ Malay language (Bahasa Malaysia)  
✅ Responsive design (mobile-friendly)  
✅ Alternative link (if button doesn't work)  
✅ Expiry warning (24 hours)  
✅ Professional footer  

---

## 📍 How to Setup in Supabase

### **Step 1: Access Email Templates**

1. Go to **Supabase Dashboard**: https://app.supabase.com
2. Select your project
3. Navigate to **Authentication** > **Email Templates**
4. Find **"Confirm signup"** template

---

### **Step 2: Copy Template**

1. Open `supabase_email_templates/email_confirmation_template.html`
2. Copy **ALL** the HTML content
3. Paste into Supabase **"Confirm signup"** template editor

---

### **Step 3: Configure Template Variables**

Make sure these variables are in the template:

- `{{ .ConfirmationURL }}` - Link untuk confirm email (REQUIRED)
- `{{ .Email }}` - User's email (optional, boleh tambah)
- `{{ .Token }}` - Confirmation token (optional, usually not needed)

**Current template uses:**
- ✅ `{{ .ConfirmationURL }}` - Main confirmation link

---

### **Step 4: Test Email**

1. Save the template in Supabase
2. Create a test account
3. Check email inbox
4. Verify email looks good on:
   - Desktop email clients (Gmail, Outlook)
   - Mobile email clients
   - Dark mode (if supported)

---

## 🎨 Customization Options

### **Colors:**

Current template uses PocketBizz gradient:
- Primary: `#667eea` (Purple)
- Secondary: `#764ba2` (Deep Purple)
- Background: `#f5f5f5` (Light Gray)
- Text: `#1a1a1a` (Dark Gray)

**To change colors:**
1. Find `background: linear-gradient(135deg, #667eea 0%, #764ba2 100%)`
2. Replace with your preferred colors
3. Update button color to match

---

### **Language:**

Current template uses **Bahasa Malaysia**.

**To change to English:**
- Replace all Malay text with English
- Update greetings and messages

**To change to other languages:**
- Translate all text content
- Keep HTML structure intact

---

### **Logo Setup (IMPORTANT):**

**Current template includes logo placeholder. You need to:**

1. **Upload logo to public URL:**
   - Option 1: Supabase Storage (Public bucket)
   - Option 2: Firebase Hosting (if using Firebase)
   - Option 3: CDN (Cloudflare, etc.)
   - Option 4: GitHub (via raw.githubusercontent.com)

2. **Replace logo URL in template:**
   ```html
   <!-- Find this line in template: -->
   <img src="https://your-cdn-url.com/pocketbizz-logo.png" ...>
   
   <!-- Replace with your actual logo URL: -->
   <img src="https://your-actual-url.com/pocketbizz-logo.png" ...>
   ```

3. **Recommended logo specs:**
   - Format: PNG with transparent background
   - Size: 160x160px or 200x200px (will be resized to 80x80px)
   - File: Use `assets/images/transparentlogo2.png` or `assets/images/Logowithtext1024x512edited.png`

4. **Quick setup options:**

   **Option A: Supabase Storage (Recommended)**
   ```bash
   # 1. Go to Supabase Dashboard > Storage
   # 2. Create bucket: "public-assets" (make it public)
   # 3. Upload logo: assets/images/transparentlogo2.png
   # 4. Copy public URL
   # 5. Update template with URL
   ```

   **Option B: Firebase Hosting**
   ```bash
   # 1. Copy logo to public folder
   cp assets/images/transparentlogo2.png public/pocketbizz-logo.png
   # 2. Deploy to Firebase
   firebase deploy --only hosting
   # 3. Use URL: https://your-app.web.app/pocketbizz-logo.png
   ```

   **Option C: GitHub (Free, but slower)**
   ```bash
   # 1. Upload logo to GitHub repo
   # 2. Use raw URL:
   # https://raw.githubusercontent.com/your-username/pocketbizz/main/assets/images/transparentlogo2.png
   ```

**To change brand name:**
- Find all instances of "PocketBizz"
- Replace with your brand name

---

## 📧 Other Email Templates

### **Magic Link Template** ✅ **READY**

Magic link email template sudah dibuat dengan:
- ✅ Same PocketBizz branding & logo
- ✅ Same gradient theme (Teal to Blue)
- ✅ Security warnings (1 hour expiry, one-time use)
- ✅ Bahasa Malaysia & English versions

**Files:**
- `magic_link_template.html` (Bahasa Malaysia)
- `magic_link_template_english.html` (English)

**Setup:**
1. Go to Supabase Dashboard > Authentication > Email Templates
2. Find **"Magic Link"** template
3. Copy content from `magic_link_template.html`
4. Paste & Save

---

### **Email Change Template** ✅ **READY**

Email change confirmation template sudah dibuat dengan:
- ✅ Same PocketBizz branding & logo
- ✅ Same gradient theme (Teal to Blue)
- ✅ Shows current and new email addresses
- ✅ Security warnings (24 hour expiry, account compromise warning)
- ✅ Bahasa Malaysia & English versions

**Files:**
- `email_change_template.html` (Bahasa Malaysia)
- `email_change_template_english.html` (English)

**Setup:**
1. Go to Supabase Dashboard > Authentication > Email Templates
2. Find **"Change Email Address"** template
3. Copy content from `email_change_template.html`
4. Paste & Save

**Template Variables:**
- `{{ .Email }}` - Current email address
- `{{ .NewEmail }}` - New email address
- `{{ .ConfirmationURL }}` - Confirmation link URL

---

### **Password Reset Template** ✅ **READY**

Password reset email template sudah dibuat dengan:
- ✅ Same PocketBizz branding & logo
- ✅ Same gradient theme (Teal to Blue)
- ✅ Security warnings (1 hour expiry, account safety)
- ✅ Password tips box (helpful for users)
- ✅ Bahasa Malaysia & English versions

**Files:**
- `password_reset_template.html` (Bahasa Malaysia)
- `password_reset_template_english.html` (English)

**Setup:**
1. Go to Supabase Dashboard > Authentication > Email Templates
2. Find **"Reset Password"** template
3. Copy content from `password_reset_template.html`
4. Paste & Save

**Template Variables:**
- `{{ .ConfirmationURL }}` - Password reset link URL (REQUIRED)

---

### **Reauthentication Template** ✅ **READY**

Reauthentication email template sudah dibuat dengan:
- ✅ Same PocketBizz branding & logo
- ✅ Same gradient theme (Teal to Blue)
- ✅ Prominent token code display (large, easy to read)
- ✅ Security warnings (10 minute expiry, never share code)
- ✅ Step-by-step instructions
- ✅ Bahasa Malaysia & English versions

**Files:**
- `reauthentication_template.html` (Bahasa Malaysia)
- `reauthentication_template_english.html` (English)

**Setup:**
1. Go to Supabase Dashboard > Authentication > Email Templates
2. Find **"Reauthentication"** or **"Confirm reauthentication"** template
3. Copy content from `reauthentication_template.html`
4. Paste & Save

**Template Variables:**
- `{{ .Token }}` - Verification code (REQUIRED)

**Design Features:**
- Large, prominent code display (36px, monospace font)
- Gradient border around code box for emphasis
- Clear instructions on how to use the code
- Strong security warnings

---

### **All Email Templates Summary**

| Template | Status | File | Supabase Template Name |
|----------|--------|------|----------------------|
| **Email Confirmation** | ✅ Ready | `email_confirmation_template.html` | "Confirm signup" |
| **Magic Link** | ✅ Ready | `magic_link_template.html` | "Magic Link" |
| **Email Change** | ✅ Ready | `email_change_template.html` | "Change Email Address" |
| **Password Reset** | ✅ Ready | `password_reset_template.html` | "Reset Password" |
| **Reauthentication** | ✅ Ready | `reauthentication_template.html` | "Reauthentication" |

**All templates include:**
- ✅ PocketBizz logo
- ✅ Teal to Blue gradient theme
- ✅ Consistent branding
- ✅ Professional design
- ✅ Security warnings
- ✅ Mobile responsive

---

## 🧪 Testing Checklist

- [ ] Email renders correctly in Gmail (desktop)
- [ ] Email renders correctly in Gmail (mobile)
- [ ] Email renders correctly in Outlook
- [ ] Button link works correctly
- [ ] Alternative link works correctly
- [ ] Colors display correctly
- [ ] Text is readable
- [ ] Mobile responsive (narrow width)
- [ ] Dark mode compatible (optional)
- [ ] All template variables work (`{{ .ConfirmationURL }}`)

---

## 📱 Mobile Optimization

Template is already optimized for mobile:
- ✅ Max width: 600px
- ✅ Responsive padding
- ✅ Readable font sizes
- ✅ Touch-friendly button
- ✅ Word-break for long URLs

---

## 🔒 Security Notes

1. **Never modify `{{ .ConfirmationURL }}` variable** - This is required by Supabase
2. **Don't add external scripts** - Email clients block them
3. **Use inline CSS** - External stylesheets don't work in emails
4. **Test link expiry** - Make sure users understand time limit

---

## 🎯 Best Practices

✅ **DO:**
- Use simple, clear language
- Make CTA button prominent
- Include alternative link
- Add expiry warning
- Keep branding consistent
- Test across email clients

❌ **DON'T:**
- Use complex CSS (not supported)
- Use JavaScript (blocked)
- Use external stylesheets (not loaded)
- Make buttons too small
- Forget alternative link
- Skip testing

---

## 📚 Additional Resources

- [Supabase Email Templates Documentation](https://supabase.com/docs/guides/auth/auth-email-templates)
- [HTML Email Best Practices](https://www.campaignmonitor.com/dev-resources/guides/coding/)
- [Email Client CSS Support](https://www.caniemail.com/)

---

**Template Created:** December 2025  
**Status:** ✅ Ready to Use  
**Language:** Bahasa Malaysia  
**Theme:** PocketBizz Professional

