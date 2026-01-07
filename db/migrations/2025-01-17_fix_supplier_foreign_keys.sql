-- ============================================================================
-- Fix Foreign Key Constraints - Change from vendors to suppliers
-- 
-- In PocketBizz:
-- - Vendor = Kedai yang jual barang user (consignee) - untuk consignment
-- - Supplier = Pembekal bahan mentah kepada user - untuk purchase bahan
-- 
-- So shopping_cart_items and stock_items should reference suppliers (not vendors)
-- ============================================================================

BEGIN;

-- Step 1: Drop old foreign key constraint on shopping_cart_items
ALTER TABLE shopping_cart_items
DROP CONSTRAINT IF EXISTS shopping_cart_items_preferred_supplier_id_fkey;

-- Step 2: Add new foreign key constraint referencing suppliers table
ALTER TABLE shopping_cart_items
ADD CONSTRAINT shopping_cart_items_preferred_supplier_id_fkey
FOREIGN KEY (preferred_supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL;

-- Step 3: Update stock_items.supplier_id to reference suppliers (if column exists)
-- Note: This will be created by 2025-01-17_add_supplier_id_to_stock_items.sql
-- But we need to ensure it references suppliers, not vendors
DO $$
BEGIN
    -- Check if column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'stock_items' 
        AND column_name = 'supplier_id'
    ) THEN
        -- Drop old constraint if exists
        ALTER TABLE stock_items
        DROP CONSTRAINT IF EXISTS stock_items_supplier_id_fkey;
        
        -- Add new constraint referencing suppliers
        ALTER TABLE stock_items
        ADD CONSTRAINT stock_items_supplier_id_fkey
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL;
    END IF;
END $$;

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ FOREIGN KEY CONSTRAINTS FIXED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ shopping_cart_items.preferred_supplier_id → suppliers';
    RAISE NOTICE '✅ stock_items.supplier_id → suppliers';
    RAISE NOTICE '';
    RAISE NOTICE 'Note: Vendor = Consignee (jual produk user)';
    RAISE NOTICE '      Supplier = Pembekal bahan (beli bahan dari supplier)';
    RAISE NOTICE '';
END $$;

