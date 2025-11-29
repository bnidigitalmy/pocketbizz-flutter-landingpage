# 🚀 APPLY PRODUCT COSTING MIGRATION

## ⚠️ STEP 1: Apply Database Migration

Go to **Supabase Dashboard** → **SQL Editor** and run:

```sql
-- Copy and paste the entire contents of:
db/migrations/add_product_costing_fields.sql
```

**Then click "RUN"**

---

## ✅ WHAT WILL BE ADDED TO PRODUCTS TABLE:

### New Columns:
- `units_per_batch` (INTEGER) - How many units produced per recipe
- `labour_cost` (NUMERIC) - Labour cost per batch
- `other_costs` (NUMERIC) - Other costs per batch (gas, electric, etc)
- `packaging_cost` (NUMERIC) - Packaging cost PER UNIT
- `materials_cost` (NUMERIC) - Calculated from recipe items
- `total_cost_per_batch` (NUMERIC) - materials + labour + other + (packaging × units)
- `cost_per_unit` (NUMERIC) - total_cost_per_batch / units_per_batch

---

## 🎯 MIGRATION IS SAFE:

- ✅ Uses `IF NOT EXISTS` checks
- ✅ Won't fail if columns already exist
- ✅ Won't affect existing product data
- ✅ Sets sensible defaults (0 for costs, 1 for units_per_batch)
- ✅ Wrapped in transaction

---

## 📱 AFTER MIGRATION:

Run your Flutter app and you'll have:

### ✅ **NEW "Tambah Produk & Resepi" Page:**
- Auto-cost calculation
- Recipe items selection (from stock gudang)
- Unit conversions (gram, kg, ml, liter, pcs, etc)
- Live cost preview
- Suggested pricing (2x, 2.5x, 3x markup)
- Mobile-first, big buttons
- Malay language
- Green/Gold theme

---

## 🔥 READY BRO?

**APPLY MIGRATION NOW!** 🚀

Then test the new product form with auto-cost calculation! 💪

