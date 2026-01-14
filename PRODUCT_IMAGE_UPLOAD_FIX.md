# 🔧 Fix: Product Image Upload Issue

## Masalah
Error "Gambar tidak berjaya dimuat naik. Anda boleh cuba tukar gambar sekali lagi." ketika upload gambar produk.

## Changes Made

### 1. ✅ Improved Error Handling & Logging

**Files Modified:**
- `lib/core/services/image_upload_service.dart`
- `lib/features/products/presentation/edit_product_page.dart`
- `lib/features/products/presentation/add_product_with_recipe_page.dart`

**Changes:**
- Added detailed error logging untuk debugging
- Show actual error message dalam snackbar (instead of generic message)
- Added debug prints untuk track upload process
- Better error context untuk identify root cause

### 2. 🔍 Debug Information Added

Sekarang akan log:
- Upload URL
- File size
- Response status code
- Response body
- Authentication status
- Bucket name
- File path

## Common Issues & Solutions

### Issue 1: Storage Bucket Tidak Wujud
**Error:** `Bucket "product-images" not found` atau `404 Not Found`

**Solution:**
1. Pergi ke Supabase Dashboard
2. Storage > New Bucket
3. Name: `product-images`
4. Public: ✅ YES
5. Create bucket

### Issue 2: Storage Policies Tidak Configure
**Error:** `403 Forbidden` atau `new row violates row-level security policy`

**Solution:**
Setup Storage Policies untuk bucket `product-images`:

1. Go to Supabase Dashboard > Storage > Policies
2. Select bucket `product-images`
3. Create 4 policies:

**Policy 1: Allow Authenticated Uploads**
- Name: `Allow authenticated uploads`
- Operation: `INSERT`
- Definition: `bucket_id = 'product-images'`
- Roles: `authenticated`

**Policy 2: Allow Authenticated Reads**
- Name: `Allow authenticated reads`
- Operation: `SELECT`
- Definition: `bucket_id = 'product-images'`
- Roles: `authenticated`

**Policy 3: Allow Authenticated Deletes**
- Name: `Allow authenticated deletes`
- Operation: `DELETE`
- Definition: `bucket_id = 'product-images'`
- Roles: `authenticated`

**Policy 4: Allow Public Reads** (Optional)
- Name: `Allow public reads`
- Operation: `SELECT`
- Definition: `bucket_id = 'product-images'`
- Roles: `public`

### Issue 3: User Not Authenticated
**Error:** `User not authenticated` atau `401 Unauthorized`

**Solution:**
- Pastikan user dah login
- Check token expiration
- Re-login jika perlu

### Issue 4: Web Upload Endpoint Issue
**Error:** `Upload failed: 400/500` pada web

**Solution:**
- Check Supabase URL & API key dalam .env
- Verify endpoint format: `https://[project].supabase.co/storage/v1/object/[bucket]/[path]`
- Check CORS settings jika perlu

## Testing

### Test Image Upload
1. Buka app
2. Pergi ke Products > Add/Edit Product
3. Pilih gambar dari gallery/camera
4. Save product
5. Check console logs untuk detailed error (jika ada)

### Verify Bucket Setup
Guna test page: `lib/features/products/presentation/test_image_upload_page.dart`

1. Navigate ke test page
2. Click "Check Bucket Access"
3. Try upload image
4. Check error messages

## Next Steps

Jika masih ada issue:
1. Check console logs untuk detailed error
2. Verify bucket wujud dalam Supabase Dashboard
3. Verify storage policies configured
4. Check authentication status
5. Test dengan test_image_upload_page.dart

## Files Changed

1. `lib/core/services/image_upload_service.dart`
   - Added detailed logging
   - Better error messages
   - Mobile upload error handling

2. `lib/features/products/presentation/edit_product_page.dart`
   - Show actual error dalam snackbar
   - Added debugPrint untuk error logging

3. `lib/features/products/presentation/add_product_with_recipe_page.dart`
   - Show actual error dalam snackbar
   - Added debugPrint untuk error logging
