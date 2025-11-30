# Apply Migration: Stock Validation untuk Production

## Migration File
`db/migrations/create_record_production_batch_function.sql`

## Changes
- Added stock validation BEFORE deducting stock
- Prevent negative stock dengan clear error messages
- Two-pass validation: Check first, then deduct

## Cara Apply Migration

### Option 1: Supabase Dashboard (Recommended)
1. Buka Supabase Dashboard: https://app.supabase.com
2. Pilih project anda
3. Pergi ke **SQL Editor**
4. Copy semua content dari `db/migrations/create_record_production_batch_function.sql`
5. Paste dalam SQL Editor
6. Click **Run** atau tekan `Ctrl+Enter`
7. Check untuk success message

### Option 2: Supabase CLI
```bash
# Jika ada Supabase CLI installed
supabase db push

# Atau direct SQL execution
supabase db execute -f db/migrations/create_record_production_batch_function.sql
```

### Option 3: psql (Direct Database Connection)
```bash
# Get connection string dari Supabase Dashboard
# Settings > Database > Connection string (URI)

psql "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres" \
  -f db/migrations/create_record_production_batch_function.sql
```

## Verification

Selepas apply migration, verify function dengan:

```sql
-- Check function exists
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name = 'record_production_batch';

-- Test function (optional - jangan run kalau tak ada test data)
-- SELECT record_production_batch(
--   'product-uuid-here'::uuid,
--   10,
--   CURRENT_DATE,
--   NULL,
--   NULL,
--   NULL
-- );
```

## Important Notes

✅ **Safe to run**: File sudah ada `DROP FUNCTION IF EXISTS` - akan replace existing function
✅ **No data loss**: Function hanya update logic, tidak affect existing data
✅ **Backward compatible**: Function signature sama, hanya tambah validation

## After Migration

1. Restart Flutter app
2. Test production dengan insufficient stock - should block dengan error message
3. Test production dengan sufficient stock - should work normally

## Rollback (if needed)

Jika perlu rollback, boleh restore previous version dari git history atau manual create function tanpa stock validation.

