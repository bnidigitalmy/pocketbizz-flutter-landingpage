# 🖼️ LANDING PAGE IMAGES MIGRATION GUIDE
**Date:** 2026-01-06  
**Status:** RLS Policies ✅ Complete  
**Next:** Upload Images & Update HTML

---

## 📋 SUPABASE CONFIGURATION

**Project URL:** `https://gxllowlurizrkvpdircw.supabase.co`  
**Bucket Name:** `landing-page`  
**Public URL Format:**
```
https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/{path}
```

---

## 🚀 STEP-BY-STEP MIGRATION

### **Step 1: Upload Images to Supabase Storage**

**Via Supabase Dashboard:**
1. Go to **Storage** > **landing-page** bucket
2. Click **Upload** button
3. Upload all images from `landing/assets/images/`

**Recommended Folder Structure:**
```
landing-page/
  ├── screenshots/
  │   ├── dashboard_baru.png
  │   ├── produk_kos3.png
  │   ├── delivery.png
  │   ├── booking.png
  │   ├── laporan2.png
  │   ├── scan_resit.png
  │   ├── Production2.png
  │   └── stok2.png
  ├── logos/
  │   ├── logo.png
  │   ├── logowithtext.png
  │   └── transparentlogo2.png
  └── marketing/
      ├── sarapan_pagi_v2.png
      └── founder_pocketbizz.png
```

**Or Flat Structure (Simpler):**
```
landing-page/
  ├── dashboard_baru.png
  ├── produk_kos3.png
  ├── delivery.png
  ├── booking.png
  ├── laporan2.png
  ├── scan_resit.png
  ├── Production2.png
  ├── stok2.png
  ├── sarapan_pagi_v2.png
  └── founder_pocketbizz.png
```

---

### **Step 2: Get Public URLs**

**For each uploaded image, get public URL:**

**Format:**
```
https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/{filename}
```

**Examples:**
```
https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/dashboard_baru.png
https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/produk_kos3.png
https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/delivery.png
```

**How to get URL:**
1. Click on image in Supabase Dashboard
2. Click **Copy URL** button
3. Or right-click > Copy URL

---

### **Step 3: Update HTML Paths**

**Current paths in `landing/index.html` (10 images):**

| Current Path | New Supabase URL |
|-------------|------------------|
| `assets/images/dashboard_baru.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/dashboard_baru.png` |
| `assets/images/Production2.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/Production2.png` |
| `assets/images/produk_kos3.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/produk_kos3.png` |
| `assets/images/stok2.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/stok2.png` |
| `assets/images/delivery.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/delivery.png` |
| `assets/images/booking.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/booking.png` |
| `assets/images/laporan2.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/laporan2.png` |
| `assets/images/scan_resit.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/scan_resit.png` |
| `assets/images/sarapan_pagi_v2.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/sarapan_pagi_v2.png` |
| `assets/images/founder_pocketbizz.png` | `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/founder_pocketbizz.png` |

---

## 🔧 QUICK REPLACE SCRIPT

**Option 1: Manual Find & Replace**

In `landing/index.html`, replace:
```
src="assets/images/
```
With:
```
src="https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/
```

**Option 2: Use Environment Variable (Better)**

Add to HTML head:
```html
<script>
  const SUPABASE_STORAGE_URL = 'https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page';
</script>
```

Then use in images:
```html
<img src="${SUPABASE_STORAGE_URL}/dashboard_baru.png">
```

**Option 3: JavaScript Replacement (Dynamic)**

Add before closing `</body>`:
```html
<script>
  // Replace all local image paths with Supabase URLs
  document.querySelectorAll('img[src^="assets/images/"]').forEach(img => {
    const filename = img.src.split('/').pop();
    img.src = `https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/${filename}`;
  });
</script>
```

---

## ✅ VERIFICATION CHECKLIST

After migration:

- [ ] All 10 images uploaded to Supabase Storage
- [ ] All images accessible via public URLs
- [ ] HTML paths updated
- [ ] Test: Open landing page in browser
- [ ] Test: Check browser console for 404 errors
- [ ] Test: Verify images load correctly
- [ ] Test: Check page load speed (should be faster)

---

## 🧪 TESTING

### **Test 1: Direct URL Access**
Open in browser:
```
https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/dashboard_baru.png
```

**Expected:** Image loads ✅

### **Test 2: Landing Page**
1. Open `landing/index.html` in browser
2. Check all images load
3. Open browser DevTools > Network tab
4. Verify no 404 errors for images

### **Test 3: Performance**
1. Check page load time (should be faster with CDN)
2. Check Core Web Vitals (LCP should improve)

---

## 📝 NOTES

1. **Keep Local Assets as Backup**
   - Don't delete `landing/assets/images/` yet
   - Keep for fallback if needed

2. **Image Optimization**
   - Consider compressing images before upload
   - Use WebP format for better compression
   - Resize large images to appropriate dimensions

3. **Caching**
   - Supabase Storage automatically sets cache headers
   - Images cached for 1 hour by default
   - CDN caches for better performance

4. **Future Updates**
   - Easy to update images without redeploy
   - Just upload new image with same name
   - Or upload with new name and update HTML

---

## 🎯 NEXT STEPS

1. ✅ **Upload images** to Supabase Storage
2. ✅ **Update HTML paths** in `landing/index.html`
3. ✅ **Test** all images load correctly
4. ✅ **Deploy** updated landing page
5. ⚠️ **Monitor** performance improvements

---

**Migration File:** `db/migrations/setup_landing_page_storage_policies.sql` ✅  
**Verified By:** Corey (AI Assistant)  
**Date:** 2025-01-16  
**Status:** ✅ Ready for Image Upload

