# 🖼️ LANDING PAGE STORAGE SETUP GUIDE
**Date:** 2025-01-16  
**Purpose:** Setup Supabase Storage untuk landing page images dengan RLS policies

---

## ✅ JAWAPAN: PERLU SET RLS POLICY

**Walaupun bucket public, RLS policy tetap perlu untuk:**
1. ✅ **Security best practice** - explicit access control
2. ✅ **Prevent unauthorized uploads** - only authenticated users can upload
3. ✅ **Audit trail** - track who uploaded what
4. ✅ **Future flexibility** - mudah ubah access rules later

---

## 🚀 SETUP STEPS

### **Step 1: Create Public Bucket**

**Via Supabase Dashboard:**
1. Go to **Storage** > **New Bucket**
2. **Name**: `landing-page`
3. **Public**: ✅ **YES** (untuk public access)
4. **File size limit**: 5MB (or higher untuk large screenshots)
5. **Allowed MIME types**: `image/jpeg, image/png, image/webp, image/svg+xml`

---

### **Step 2: Set RLS Policies**

**Option A: Via SQL (Recommended)**

Run migration file:
```sql
-- File: db/migrations/setup_landing_page_storage_policies.sql
```

**Option B: Via Supabase Dashboard**

1. Go to **Storage** > **Policies** > **landing-page**
2. Click **New Policy**

**Policy 1: Public View (SELECT)**
- **Name**: "Public can view landing page images"
- **Operation**: SELECT
- **Target roles**: `public`
- **Policy definition**:
  ```sql
  bucket_id = 'landing-page'
  ```

**Policy 2: Authenticated Upload (INSERT)**
- **Name**: "Authenticated users can upload landing page images"
- **Operation**: INSERT
- **Target roles**: `authenticated`
- **Policy definition**:
  ```sql
  bucket_id = 'landing-page'
  ```

**Policy 3: Authenticated Delete (DELETE)**
- **Name**: "Authenticated users can delete landing page images"
- **Operation**: DELETE
- **Target roles**: `authenticated`
- **Policy definition**:
  ```sql
  bucket_id = 'landing-page'
  ```

**Policy 4: Authenticated Update (UPDATE)**
- **Name**: "Authenticated users can update landing page images"
- **Operation**: UPDATE
- **Target roles**: `authenticated`
- **Policy definition**:
  ```sql
  bucket_id = 'landing-page'
  ```

---

## 🔒 RLS POLICIES EXPLAINED

### **1. Public SELECT (View)**
```sql
CREATE POLICY "Public can view landing page images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'landing-page');
```

**Purpose:** Allow semua orang (termasuk unauthenticated) untuk view images
**Why:** Landing page perlu accessible to everyone

---

### **2. Authenticated INSERT (Upload)**
```sql
CREATE POLICY "Authenticated users can upload landing page images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'landing-page');
```

**Purpose:** Only authenticated users boleh upload
**Why:** Prevent unauthorized uploads, spam, abuse

---

### **3. Authenticated DELETE**
```sql
CREATE POLICY "Authenticated users can delete landing page images"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'landing-page');
```

**Purpose:** Only authenticated users boleh delete
**Why:** Prevent accidental or malicious deletion

---

### **4. Authenticated UPDATE**
```sql
CREATE POLICY "Authenticated users can update landing page images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'landing-page')
WITH CHECK (bucket_id = 'landing-page');
```

**Purpose:** Only authenticated users boleh update
**Why:** Control who can modify images

---

## 📋 VERIFICATION CHECKLIST

After setup, verify:

- [ ] Bucket created: `landing-page`
- [ ] Bucket is **public** ✅
- [ ] RLS Policy 1: Public SELECT exists
- [ ] RLS Policy 2: Authenticated INSERT exists
- [ ] RLS Policy 3: Authenticated DELETE exists
- [ ] RLS Policy 4: Authenticated UPDATE exists
- [ ] Test: Upload image (as authenticated user) ✅
- [ ] Test: View image (as unauthenticated user) ✅
- [ ] Test: Public URL works ✅

---

## 🧪 TESTING

### **Test 1: Public Access (Should Work)**
```bash
# Get public URL
https://{project-ref}.supabase.co/storage/v1/object/public/landing-page/test.png

# Should load without authentication
```

### **Test 2: Upload (Should Require Auth)**
```javascript
// Without auth - should fail
await supabase.storage
  .from('landing-page')
  .upload('test.png', file);

// With auth - should work
await supabase.storage
  .from('landing-page')
  .upload('test.png', file);
```

---

## ⚠️ IMPORTANT NOTES

1. **Bucket must be PUBLIC** - untuk public URLs
2. **RLS policies are REQUIRED** - walaupun bucket public
3. **Public SELECT is ESSENTIAL** - untuk images accessible
4. **Authenticated INSERT/DELETE/UPDATE** - untuk security

---

## 🔍 TROUBLESHOOTING

### **Issue: Images not loading**
- ✅ Check bucket is **public**
- ✅ Check RLS Policy for **public SELECT** exists
- ✅ Check URL format is correct

### **Issue: Cannot upload**
- ✅ Check user is **authenticated**
- ✅ Check RLS Policy for **authenticated INSERT** exists
- ✅ Check bucket name is correct

### **Issue: 403 Forbidden**
- ✅ Check RLS policies are active
- ✅ Check bucket is public
- ✅ Check policy definition matches bucket_id

---

## ✅ CONCLUSION

**YES, perlu set RLS policies walaupun bucket public!**

**Reasons:**
1. ✅ Security best practice
2. ✅ Explicit access control
3. ✅ Prevent unauthorized uploads
4. ✅ Better audit trail
5. ✅ Future flexibility

**Setup:**
1. Create bucket (public)
2. Set 4 RLS policies (SELECT public, INSERT/DELETE/UPDATE authenticated)
3. Test access
4. Upload images
5. Update HTML paths

---

**Migration File:** `db/migrations/setup_landing_page_storage_policies.sql`  
**Verified By:** Corey (AI Assistant)  
**Date:** 2025-01-16  
**Status:** ✅ Ready to Deploy

