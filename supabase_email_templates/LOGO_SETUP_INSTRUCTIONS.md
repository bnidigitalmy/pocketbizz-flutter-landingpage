# 📸 PocketBizz Logo Setup untuk Email Template

## 🎯 Quick Steps

Template email sekarang sudah include logo placeholder. Anda perlu replace dengan logo URL yang actual.

---

## ✅ Method 1: Supabase Storage (Recommended)

### **Steps:**

1. **Go to Supabase Dashboard:**
   - Navigate to **Storage**
   - Click **New bucket**
   - Name: `public-assets`
   - **Make it PUBLIC** ✅ (important!)

2. **Upload Logo:**
   - Click on `public-assets` bucket
   - Click **Upload file**
   - Select: `assets/images/transparentlogo2.png`
   - Or: `assets/images/Logowithtext1024x512edited.png` (if you want logo with text)

3. **Get Public URL:**
   - Right-click on uploaded file
   - Select **Copy URL**
   - URL format: `https://your-project.supabase.co/storage/v1/object/public/public-assets/transparentlogo2.png`

4. **Update Email Template:**
   - Open `supabase_email_templates/email_confirmation_template.html`
   - Find: `<img src="https://your-cdn-url.com/pocketbizz-logo.png"`
   - Replace with your Supabase Storage URL

---

## ✅ Method 2: Firebase Hosting (If using Firebase)

### **Steps:**

1. **Copy logo to public folder:**
   ```bash
   cp assets/images/transparentlogo2.png public/pocketbizz-logo.png
   ```

2. **Deploy to Firebase:**
   ```bash
   firebase deploy --only hosting
   ```

3. **Get URL:**
   - URL: `https://your-app-id.web.app/pocketbizz-logo.png`
   - Or: `https://your-domain.com/pocketbizz-logo.png`

4. **Update Email Template:**
   - Replace logo URL in template

---

## ✅ Method 3: GitHub (Free, but slower loading)

### **Steps:**

1. **Commit logo to GitHub:**
   ```bash
   git add assets/images/transparentlogo2.png
   git commit -m "Add logo for email template"
   git push
   ```

2. **Get Raw URL:**
   - Go to GitHub repo
   - Navigate to `assets/images/transparentlogo2.png`
   - Click **Raw** button
   - Copy URL
   - Format: `https://raw.githubusercontent.com/your-username/pocketbizz/main/assets/images/transparentlogo2.png`

3. **Update Email Template:**
   - Replace logo URL in template

---

## ✅ Method 4: CDN (Cloudflare, AWS S3, etc.)

### **Steps:**

1. Upload logo to your CDN
2. Make it publicly accessible
3. Copy public URL
4. Update email template

---

## 📝 Update Template

### **Find this in template:**

```html
<img src="https://your-cdn-url.com/pocketbizz-logo.png" 
     alt="PocketBizz Logo" 
     width="80" 
     height="80" 
     style="width: 80px; height: 80px; margin: 0 auto 16px; display: block; border-radius: 12px; background-color: rgba(255,255,255,0.1); padding: 8px;">
```

### **Replace with:**

```html
<img src="YOUR_ACTUAL_LOGO_URL_HERE" 
     alt="PocketBizz Logo" 
     width="80" 
     height="80" 
     style="width: 80px; height: 80px; margin: 0 auto 16px; display: block; border-radius: 12px; background-color: rgba(255,255,255,0.1); padding: 8px;">
```

---

## 🎨 Logo Recommendations

### **Best Choice:**
- **File:** `assets/images/transparentlogo2.png`
- **Why:** Transparent background, works well on gradient header
- **Size:** Original size is fine (will be resized to 80x80px in email)

### **Alternative (Logo with Text):**
- **File:** `assets/images/Logowithtext1024x512edited.png`
- **Why:** Includes "PocketBizz" text, more recognizable
- **Note:** May need to adjust width/height ratio (2:1)

---

## 🧪 Testing

After updating logo URL:

1. **Save template** in Supabase
2. **Create test account**
3. **Check email** in inbox
4. **Verify:**
   - ✅ Logo displays correctly
   - ✅ Logo is not broken (no red X)
   - ✅ Logo looks good on gradient background
   - ✅ Logo loads quickly

---

## ⚠️ Common Issues

### **Logo doesn't show:**
- ❌ Check URL is accessible (open in browser)
- ❌ Check URL is publicly accessible (not private)
- ❌ Check URL has correct file extension (.png, .jpg, etc.)
- ❌ Some email clients block external images (Gmail may show "Images not displayed" warning)

### **Logo is too big/small:**
- Adjust `width` and `height` attributes
- Recommended: 80x80px for email

### **Logo looks blurry:**
- Use high-resolution logo (at least 160x160px)
- PNG format is better than JPG for logos

---

## 📚 Additional Resources

- [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
- [Email Image Best Practices](https://www.campaignmonitor.com/dev-resources/guides/coding/)
- [HTML Email Image Guide](https://www.emailonacid.com/blog/article/email-development/emailology-html-email-image-guide/)

---

**Last Updated:** December 2025  
**Status:** ✅ Template Ready (needs logo URL update)

