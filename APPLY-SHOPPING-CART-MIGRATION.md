# 🛒 APPLY SHOPPING CART MIGRATION

## ⚠️ STEP 1: Apply Database Migration

Go to **Supabase Dashboard** → **SQL Editor** and run:

```sql
-- Copy and paste the entire contents of:
db/migrations/add_shopping_cart.sql
```

**Then click "RUN"** ▶️

---

## ✅ **WHAT WILL BE CREATED:**

### **shopping_cart_items table:**
```sql
- id (UUID)
- business_owner_id (UUID) → Links to user
- stock_item_id (UUID) → Links to stock item
- shortage_qty (NUMERIC) → How much to buy
- notes (TEXT) → Optional notes
- priority (VARCHAR) → low/normal/high/urgent
- preferred_supplier_id (UUID) → Optional vendor link
- status (VARCHAR) → pending/ordered/received/cancelled
- ordered_at, received_at (TIMESTAMP)
- purchase_order_id (UUID)
- created_at, updated_at (TIMESTAMP)
```

### **Function:**
```sql
bulk_add_to_shopping_cart(p_items JSONB)
  → Bulk insert/update cart items
  → Returns: added count, skipped count, errors
```

### **RLS Policies:**
- ✅ Users can only see their own cart
- ✅ Users can add/update/delete their own items
- ✅ Full security enabled

---

## 🎯 **MIGRATION IS SAFE:**

- ✅ Uses `IF NOT EXISTS` checks
- ✅ Won't fail if table already exists
- ✅ Won't affect existing data
- ✅ Wrapped in transaction (auto-rollback on error)
- ✅ Includes success message

---

## 📱 **AFTER MIGRATION:**

You'll have:
- ✅ Shopping cart database
- ✅ Selection mode in Stock Page
- ✅ Bulk add to cart
- ✅ Shopping list management
- ✅ Purchase order tracking

---

## 🔥 **READY BRO?**

**APPLY MIGRATION NOW!** 🚀

**Then I'll build the UI!** 💪

