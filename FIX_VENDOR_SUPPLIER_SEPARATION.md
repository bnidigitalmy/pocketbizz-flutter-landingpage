# Fix: Vendor & Supplier Table Separation

## 🐛 Masalah yang Ditemui

User melaporkan bahawa:
- **Module Vendor** ada list dari Supplier (❌ SALAH)
- **Module Supplier** ada list dari Vendor (❌ SALAH)  
- **Module Claims & Deliveries** ada list dari Supplier (❌ SALAH - sepatutnya Vendor sahaja)

## 🔍 Root Cause

**SuppliersRepository** sedang menggunakan `vendors` table instead of `suppliers` table!

```dart
// ❌ SALAH - Sebelum fix
final response = await supabase
    .from('vendors')  // <-- SALAH! Sepatutnya 'suppliers'
    .select()
```

Ini menyebabkan:
- Suppliers module show vendors data
- Vendors module mungkin show suppliers data (jika ada confusion)
- Data mixing antara vendors dan suppliers

## ✅ Pembetulan yang Dibuat

### 1. Fix SuppliersRepository (`lib/data/repositories/suppliers_repository_supabase.dart`)

**Changed:**
- ✅ `getAllSuppliers()`: `.from('vendors')` → `.from('suppliers')`
- ✅ `getSupplierById()`: `.from('vendors')` → `.from('suppliers')`
- ✅ `createSupplier()`: `.from('vendors')` → `.from('suppliers')`
- ✅ `updateSupplier()`: `.from('vendors')` → `.from('suppliers')`
- ✅ `deleteSupplier()`: `.from('vendors')` → `.from('suppliers')`
- ✅ Updated comment: "Uses suppliers table (separate from vendors table)"

### 2. Add Email Column to Suppliers Table

**Migration Created:** `db/migrations/2025-01-16_add_email_to_suppliers.sql`

```sql
-- Add email column to suppliers table
ALTER TABLE suppliers
ADD COLUMN IF NOT EXISTS email TEXT;

-- Add index for email
CREATE INDEX IF NOT EXISTS idx_suppliers_email ON suppliers (email) WHERE email IS NOT NULL;
```

**Schema Updated:** `db/schema.sql`
- ✅ Added `email TEXT` column to suppliers table definition
- ✅ Added index for email column

### 3. Update Supplier Model Comment

**File:** `lib/data/models/supplier.dart`
- ✅ Updated comment: "Uses suppliers table (separate from vendors table)"

## 📊 Verification

### ✅ Vendors Module
- Uses: `VendorsRepositorySupabase`
- Table: `vendors` ✅
- Status: **BETUL**

### ✅ Suppliers Module  
- Uses: `SuppliersRepository`
- Table: `suppliers` ✅ (FIXED)
- Status: **BETUL**

### ✅ Claims Module
- Uses: `VendorsRepositorySupabase` ✅
- Table: `vendors` ✅
- Status: **BETUL**

### ✅ Deliveries Module
- Uses: `VendorsRepositorySupabase` ✅
- Table: `vendors` ✅
- Status: **BETUL**

## 🎯 Result

Sekarang setiap module menggunakan table yang betul:
- **Vendors** = `vendors` table (untuk consignment system)
- **Suppliers** = `suppliers` table (untuk purchase/production system)
- **Claims & Deliveries** = `vendors` table (betul, kerana part of consignment)

## ✅ Migration Status

**Date Applied:** 2025-01-16
**Migration:** `2025-01-16_add_email_to_suppliers.sql`
**Status:** ✅ **APPLIED**

## 📝 Testing Checklist

**Please verify:**
1. ✅ Suppliers module - should show suppliers only (from `suppliers` table)
2. ✅ Vendors module - should show vendors only (from `vendors` table)
3. ✅ Claims module - should show vendors only (correct)
4. ✅ Deliveries module - should show vendors only (correct)
5. ✅ Create new supplier - should save to `suppliers` table
6. ✅ Create new vendor - should save to `vendors` table
7. ✅ Supplier email field - should work (save & display)

## 📋 Verification Steps

**1. Test Suppliers Module:**
- Go to Suppliers page
- Should only show suppliers (not vendors)
- Add new supplier with email
- Verify email field works

**2. Test Vendors Module:**
- Go to Vendors page  
- Should only show vendors (not suppliers)
- Create new vendor
- Verify commission settings work

**3. Test Claims/Deliveries:**
- Go to Claims page
- Vendor dropdown should only show vendors
- Go to Deliveries page
- Vendor dropdown should only show vendors

## ⚠️ Important Notes

1. **Data Migration (if needed):**
   - Jika ada existing suppliers data dalam `vendors` table yang perlu dipindah ke `suppliers` table, perlu buat data migration script
   - Check dengan user jika ada data yang perlu dipindah

2. **Email Column:**
   - Email column sudah ditambah ke `suppliers` table
   - Supplier model sudah support email field
   - UI sudah ada email field
   - Semua sudah sync ✅

---

**Date:** 2025-01-16
**Status:** ✅ **FIXED & MIGRATED**

**Migration Applied:** ✅ Done
**Code Fixed:** ✅ Complete
**Schema Updated:** ✅ Complete
**Ready for Testing:** ✅ Yes

