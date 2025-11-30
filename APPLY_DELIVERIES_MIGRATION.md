# Apply Migration: Vendor Deliveries System

## Migration File
`db/migrations/add_vendor_deliveries.sql`

## Changes
- Create `vendor_deliveries` table untuk rekod penghantaran ke vendor
- Create `vendor_delivery_items` table untuk items dalam setiap penghantaran
- Auto-generate invoice number (format: DEL-YYMM-0001)
- Support untuk rejection tracking (rejected_qty, rejection_reason)
- Payment status tracking (pending, partial, settled)
- RLS policies untuk security

## Tables Created

### 1. `vendor_deliveries`
- Delivery header dengan vendor info, date, status, payment status
- Auto-generated invoice number
- Total amount calculation

### 2. `vendor_delivery_items`
- Items dalam setiap delivery
- Product info, quantity, pricing
- Rejection tracking (rejected_qty, rejection_reason)
- Retail price untuk commission calculation reference

## Cara Apply Migration

### Option 1: Supabase Dashboard (Recommended)
1. Buka Supabase Dashboard: https://app.supabase.com
2. Pilih project anda
3. Pergi ke **SQL Editor**
4. Copy semua content dari `db/migrations/add_vendor_deliveries.sql`
5. Paste dalam SQL Editor
6. Click **Run** atau tekan `Ctrl+Enter`
7. Check untuk success message

### Option 2: Supabase CLI
```bash
# Jika ada Supabase CLI installed
supabase db push

# Atau direct SQL execution
supabase db execute -f db/migrations/add_vendor_deliveries.sql
```

### Option 3: psql (Direct Database Connection)
```bash
# Get connection string dari Supabase Dashboard
# Settings > Database > Connection string (URI)

psql "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres" \
  -f db/migrations/add_vendor_deliveries.sql
```

## Verification

Selepas apply migration, verify tables dengan:

```sql
-- Check tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('vendor_deliveries', 'vendor_delivery_items');

-- Check indexes
SELECT indexname, tablename 
FROM pg_indexes 
WHERE tablename IN ('vendor_deliveries', 'vendor_delivery_items');

-- Check RLS policies
SELECT tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('vendor_deliveries', 'vendor_delivery_items');

-- Check function exists
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name = 'generate_delivery_invoice_number';
```

## Important Notes

✅ **Safe to run**: File sudah ada `DROP TABLE IF EXISTS` - akan replace existing tables jika ada
⚠️ **Data loss warning**: Jika tables sudah wujud dengan data, data akan hilang. Backup dulu jika perlu!
✅ **RLS enabled**: Tables sudah ada Row Level Security untuk data isolation
✅ **Auto invoice number**: Invoice number akan auto-generate pada format DEL-YYMM-0001

## Table Structure

### vendor_deliveries
- `id` - UUID primary key
- `business_owner_id` - Foreign key to users
- `vendor_id` - Foreign key to vendors
- `vendor_name` - Denormalized vendor name
- `delivery_date` - Date of delivery
- `status` - delivered, pending, claimed, rejected
- `payment_status` - pending, partial, settled (nullable)
- `total_amount` - Total delivery amount
- `invoice_number` - Auto-generated invoice number
- `notes` - Optional notes
- `created_at`, `updated_at` - Timestamps

### vendor_delivery_items
- `id` - UUID primary key
- `delivery_id` - Foreign key to vendor_deliveries
- `product_id` - Foreign key to products
- `product_name` - Denormalized product name
- `quantity` - Quantity delivered
- `unit_price` - Price per unit (after commission)
- `total_price` - Total price for this item
- `retail_price` - Original retail price (before commission)
- `rejected_qty` - Quantity rejected (default 0)
- `rejection_reason` - Reason for rejection (nullable)
- `created_at`, `updated_at` - Timestamps

## After Migration

1. Restart Flutter app
2. Test create delivery - should auto-generate invoice number
3. Test add items to delivery
4. Test update rejection
5. Test update payment status

## Rollback (if needed)

Jika perlu rollback, boleh drop tables:

```sql
DROP TABLE IF EXISTS vendor_delivery_items CASCADE;
DROP TABLE IF EXISTS vendor_deliveries CASCADE;
DROP FUNCTION IF EXISTS generate_delivery_invoice_number();
DROP FUNCTION IF EXISTS set_delivery_invoice_number();
DROP FUNCTION IF EXISTS update_vendor_deliveries_updated_at();
```

## Integration Notes

- Delivery module sudah ready untuk integrate dengan:
  - **Vendors module** - untuk vendor selection
  - **Products module** - untuk product selection
  - **Claims module** - untuk vendor claims (future)
  - **Payments module** - untuk vendor payments (future)

