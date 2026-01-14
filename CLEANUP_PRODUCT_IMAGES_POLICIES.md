# 🧹 Cleanup Product Images Storage Policies

## Status
✅ **Upload gambar dah berjaya!**  
✅ **Error 400 dah hilang!**  
⚠️ **Perlu cleanup policies lama untuk pastikan konfigurasi betul**

---

## Cara Cleanup Policies

### Option 1: Guna Supabase SQL Editor (Recommended)

1. **Buka Supabase Dashboard**
   - Pergi ke: https://supabase.com/dashboard
   - Pilih project anda

2. **Buka SQL Editor**
   - Klik **SQL Editor** di sidebar kiri
   - Klik **New Query**

3. **Copy & Paste SQL**
   - Buka file: `db/migrations/fix_product_images_storage_policies.sql`
   - Copy semua content
   - Paste dalam SQL Editor

4. **Run SQL**
   - Klik **Run** button (atau tekan `Ctrl+Enter`)
   - Tunggu sampai selesai

5. **Verify Policies**
   - Pergi ke **Storage > Policies**
   - Pilih bucket **`product-images`**
   - Pastikan ada 4 policies baru (tanpa suffix `16wiy3a_0`):
     - ✅ Allow authenticated uploads
     - ✅ Allow authenticated reads
     - ✅ Allow authenticated deletes
     - ✅ Allow public reads

---

### Option 2: Guna Supabase Dashboard UI (Manual)

1. **Pergi ke Storage Policies**
   - Supabase Dashboard > **Storage** > **Policies**
   - Pilih bucket **`product-images`**

2. **Delete Policies Lama**
   - Delete semua policies yang ada suffix `16wiy3a_0`:
     - ❌ Allow authenticated uploads 16wiy3a_0
     - ❌ Allow authenticated reads 16wiy3a_0
     - ❌ Allow authenticated deletes 16wiy3a_0
     - ❌ Allow public reads 16wiy3a_0

3. **Create Policies Baru**

   **Policy 1: Allow authenticated uploads**
   - Klik **New Policy**
   - Name: `Allow authenticated uploads`
   - Operation: `INSERT`
   - Definition: `bucket_id = 'product-images'`
   - Roles: `authenticated`
   - Save

   **Policy 2: Allow authenticated reads**
   - Klik **New Policy**
   - Name: `Allow authenticated reads`
   - Operation: `SELECT`
   - Definition: `bucket_id = 'product-images'`
   - Roles: `authenticated`
   - Save

   **Policy 3: Allow authenticated deletes**
   - Klik **New Policy**
   - Name: `Allow authenticated deletes`
   - Operation: `DELETE`
   - Definition: `bucket_id = 'product-images'`
   - Roles: `authenticated`
   - Save

   **Policy 4: Allow public reads** ⚠️ **PENTING**
   - Klik **New Policy**
   - Name: `Allow public reads`
   - Operation: `SELECT`
   - Definition: `bucket_id = 'product-images'`
   - Roles: `public`
   - Save

---

## Verify Setup

Selepas cleanup, verify dengan query ini dalam SQL Editor:

```sql
SELECT 
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies 
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND (policyname LIKE '%product-images%' OR policyname LIKE '%product%');
```

**Expected Result:**
- 4 policies sahaja (tanpa suffix `16wiy3a_0`)
- Semua policies ada condition: `bucket_id = 'product-images'`
- Policy "Allow public reads" untuk `public` role

---

## Test Selepas Cleanup

1. **Upload gambar baru**
   - Buka app > Products > Add/Edit Product
   - Upload gambar
   - Pastikan berjaya tanpa error

2. **View gambar**
   - Pastikan gambar boleh display
   - Tiada error 400 dalam console

3. **Delete gambar**
   - Edit product > Delete gambar
   - Pastikan berjaya

---

## Notes

- ✅ Upload dah berjaya sekarang, jadi cleanup ni untuk pastikan policies betul untuk jangka panjang
- ✅ Policies baru lebih simple dan tidak restrictive
- ✅ Policy "Allow public reads" penting untuk app boleh display gambar tanpa authentication

---

## File Reference

- SQL Migration: `db/migrations/fix_product_images_storage_policies.sql`
- Service Code: `lib/core/services/image_upload_service.dart`
