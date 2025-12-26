# Fix Purchase Orders Supplier Foreign Key Constraint

## 🐛 Masalah yang Ditemui

**Error Message:**
```
PostgrestException(message: insert or update on table "purchase_orders" violates foreign key constraint "purchase_orders_supplier_id_fkey", code: 23503, details: Key is not present in table "vendors"., hint: null)
```

**Root Cause:**
- `purchase_orders` table ada foreign key constraint `purchase_orders_supplier_id_fkey` yang reference ke `vendors` table
- Tapi sekarang kita dah fix code untuk create supplier dalam `suppliers` table, bukan `vendors` table
- Jadi apabila kita try insert PO dengan `supplier_id` dari `suppliers` table, foreign key constraint fail kerana ia expect ID dari `vendors` table

## ✅ Pembetulan

**Migration File:** `db/migrations/2025-01-16_fix_purchase_orders_supplier_fkey.sql`

**Steps:**
1. Drop old foreign key constraint `purchase_orders_supplier_id_fkey` (yang reference ke `vendors`)
2. Update existing `supplier_id` values yang reference vendors to NULL (since we can't auto-convert)
3. Create new foreign key constraint yang reference ke `suppliers` table

**Important Notes:**
- Existing purchase orders dengan `supplier_id` yang reference vendors akan di-set ke NULL
- User perlu manually reassign suppliers untuk existing POs jika perlu
- New purchase orders akan work dengan betul selepas migration

## 🔄 Cara Apply Migration

1. Run migration file dalam Supabase SQL Editor atau via migration tool
2. Verify constraint telah updated:
   ```sql
   SELECT 
       tc.constraint_name, 
       tc.table_name, 
       kcu.column_name,
       ccu.table_name AS foreign_table_name,
       ccu.column_name AS foreign_column_name 
   FROM information_schema.table_constraints AS tc 
   JOIN information_schema.key_column_usage AS kcu
     ON tc.constraint_name = kcu.constraint_name
   JOIN information_schema.constraint_column_usage AS ccu
     ON ccu.constraint_name = tc.constraint_name
   WHERE tc.table_name='purchase_orders' 
     AND tc.constraint_name='purchase_orders_supplier_id_fkey';
   ```
3. Test dengan create new PO dengan supplier baru (manual)

## ✅ Expected Result

Selepas migration:
- ✅ New suppliers created dalam `suppliers` table boleh digunakan untuk PO
- ✅ Foreign key constraint reference ke `suppliers` table, bukan `vendors` table
- ✅ PO creation tidak akan fail dengan foreign key constraint error

---

**Date:** 2025-01-16
**Status:** ✅ **MIGRATION CREATED**

