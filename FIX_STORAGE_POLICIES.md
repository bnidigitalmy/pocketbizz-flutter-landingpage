# Fix Storage Policies - Update Bucket Name

## Masalah
Policy expressions guna `product-images` (lowercase) tapi bucket sebenar adalah `PRODUCT-IMAGES` (uppercase).

## Solution: Update Policy Expressions

### Langkah 1: Edit Setiap Policy

Untuk setiap policy yang sudah dibuat, edit expression:

1. Pergi ke **Storage > Policies > PRODUCT-IMAGES**
2. Klik **3 dots (⋮)** pada setiap policy
3. Pilih **"Edit"**
4. Update **WITH CHECK expression** atau **USING expression**:

**Tukar dari:**
```sql
bucket_id = 'product-images'::text
```

**Kepada:**
```sql
bucket_id = 'PRODUCT-IMAGES'::text
```

### Policies yang perlu di-update:

1. **Allow authenticated uploads**
   - WITH CHECK: `bucket_id = 'PRODUCT-IMAGES'::text`

2. **Allow authenticated reads**
   - USING: `bucket_id = 'PRODUCT-IMAGES'::text`

3. **Allow authenticated deletes**
   - USING: `bucket_id = 'PRODUCT-IMAGES'::text`

4. **Allow public reads**
   - USING: `bucket_id = 'PRODUCT-IMAGES'::text`

### Quick Fix: Delete dan Recreate

Atau lebih mudah, delete semua policies dan create semula dengan expression yang betul:

1. Delete semua 4 policies
2. Create semula dengan expression: `bucket_id = 'PRODUCT-IMAGES'::text`

### Verify

Selepas update, verify:
- Bucket name dalam expression match dengan bucket name sebenar: `PRODUCT-IMAGES`
- Semua policies active
- Test upload sekali lagi

