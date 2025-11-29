# Apply Purchase Orders Migration

## Steps to Apply Migration

1. **Open Supabase SQL Editor**
   - Go to your Supabase project dashboard
   - Navigate to SQL Editor

2. **Run the Safe Migration Script**
   - Copy the contents of `db/migrations/add_purchase_orders_SAFE.sql`
   - Paste into SQL Editor
   - Click "Run" or press Ctrl+Enter

3. **Verify Tables Created**
   - Check that `purchase_orders` table exists
   - Check that `purchase_order_items` table exists
   - Verify columns match the schema

## What This Migration Does

- Creates `purchase_orders` table with all required fields
- Creates `purchase_order_items` table for PO line items
- Sets up RLS (Row Level Security) policies
- Creates indexes for performance
- Creates `receive_purchase_order()` function for auto-updating stock

## Important Notes

⚠️ **WARNING**: The SAFE version will **DROP** existing `purchase_orders` and `purchase_order_items` tables if they exist. This is to avoid column name conflicts.

If you have existing data in these tables, you should:
1. Export the data first
2. Apply the migration
3. Re-import the data (may need to adjust column names)

## Troubleshooting

### Error: "column po_number does not exist"
- This means the table exists but with different column names
- Use the SAFE version which drops and recreates the table

### Error: "relation purchase_orders already exists"
- The SAFE version handles this by dropping first
- If you still get this error, manually drop the table first:
  ```sql
  DROP TABLE IF EXISTS purchase_order_items CASCADE;
  DROP TABLE IF EXISTS purchase_orders CASCADE;
  ```

### Error: "function record_stock_movement does not exist"
- Make sure you've applied the stock management migrations first
- The `record_stock_movement` function should exist from previous migrations

