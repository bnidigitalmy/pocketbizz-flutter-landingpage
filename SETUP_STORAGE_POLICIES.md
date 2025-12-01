# Setup Supabase Storage Policies untuk product-images Bucket

## Masalah
Error "403 Unauthorized" dan "new row violates row-level security policy" ketika upload images.

## Solution: Setup Policies melalui Supabase Dashboard

### Langkah 1: Buka Storage Policies
1. Pergi ke [Supabase Dashboard](https://supabase.com/dashboard)
2. Pilih project anda
3. Klik **Storage** di sidebar kiri
4. Klik **Policies** tab
5. Pilih bucket **`product-images`**

### Langkah 2: Create Policy 1 - Allow Authenticated Uploads

1. Klik **"New Policy"** button
2. Pilih **"Create a policy from scratch"**
3. Isi maklumat berikut:
   - **Policy name:** `Allow authenticated uploads`
   - **Allowed operation:** `INSERT`
   - **Policy definition:** 
     ```sql
     bucket_id = 'PRODUCT-IMAGES'
     ```
   - **Target roles:** Pilih `authenticated`
4. Klik **"Review"** kemudian **"Save policy"**

### Langkah 3: Create Policy 2 - Allow Authenticated Reads

1. Klik **"New Policy"** button
2. Pilih **"Create a policy from scratch"**
3. Isi maklumat berikut:
   - **Policy name:** `Allow authenticated reads`
   - **Allowed operation:** `SELECT`
   - **Policy definition:** 
     ```sql
     bucket_id = 'PRODUCT-IMAGES'
     ```
   - **Target roles:** Pilih `authenticated`
4. Klik **"Review"** kemudian **"Save policy"**

### Langkah 4: Create Policy 3 - Allow Authenticated Deletes

1. Klik **"New Policy"** button
2. Pilih **"Create a policy from scratch"**
3. Isi maklumat berikut:
   - **Policy name:** `Allow authenticated deletes`
   - **Allowed operation:** `DELETE`
   - **Policy definition:** 
     ```sql
     bucket_id = 'PRODUCT-IMAGES'
     ```
   - **Target roles:** Pilih `authenticated`
4. Klik **"Review"** kemudian **"Save policy"**

### Langkah 5: Create Policy 4 - Allow Public Reads (Optional)

Jika bucket adalah public dan anda nak allow anyone view images:

1. Klik **"New Policy"** button
2. Pilih **"Create a policy from scratch"**
3. Isi maklumat berikut:
   - **Policy name:** `Allow public reads`
   - **Allowed operation:** `SELECT`
   - **Policy definition:** 
     ```sql
     bucket_id = 'PRODUCT-IMAGES'
     ```
   - **Target roles:** Pilih `public`
4. Klik **"Review"** kemudian **"Save policy"**

## Alternative: Quick Setup dengan Template

Jika Dashboard ada template option:

1. Pilih bucket **`product-images`**
2. Klik **"New Policy"**
3. Pilih template: **"Give users access to own folder"** atau **"Public Access"**
4. Modify untuk match bucket name: `product-images`

## Verify Policies

Selepas create semua policies, verify:
1. Klik **Policies** tab untuk bucket `product-images`
2. Anda sepatutnya nampak 3-4 policies:
   - Allow authenticated uploads (INSERT)
   - Allow authenticated reads (SELECT)
   - Allow authenticated deletes (DELETE)
   - Allow public reads (SELECT) - optional

## Test Upload

Selepas setup policies:
1. Refresh Flutter app
2. Test upload image sekali lagi
3. Seharusnya berfungsi sekarang! ✅

## Troubleshooting

Jika masih dapat error:
1. Check user sudah login (authenticated)
2. Verify bucket name: `product-images` (case-sensitive)
3. Check policies target roles: `authenticated` untuk upload/delete
4. Untuk public bucket, pastikan ada public read policy

