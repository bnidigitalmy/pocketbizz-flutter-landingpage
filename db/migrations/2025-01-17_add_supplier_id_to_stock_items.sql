-- ============================================================================
-- Add supplier_id to stock_items table
-- Allows users to assign default supplier when creating stock items
-- ============================================================================

BEGIN;

-- Add supplier_id column to stock_items (references suppliers table)
-- Note: Supplier = Pembekal bahan mentah (bukan vendor/consignee)
ALTER TABLE stock_items
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL;

-- Create index for supplier lookup
CREATE INDEX IF NOT EXISTS idx_stock_items_supplier ON stock_items (supplier_id) WHERE supplier_id IS NOT NULL;

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SUPPLIER_ID ADDED TO STOCK_ITEMS!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Column: supplier_id (references vendors)';
    RAISE NOTICE '✅ Index: idx_stock_items_supplier';
    RAISE NOTICE '';
END $$;

