-- ============================================================================
-- Add package_size column to purchase_order_items table
-- 
-- This is needed to correctly calculate item totals:
-- - quantity is in base unit (gram/kg)
-- - estimated_price is price per package
-- - Need package_size to calculate: packages_needed = (quantity / package_size).ceil()
-- - Total = packages_needed * estimated_price
-- ============================================================================

BEGIN;

-- Add package_size column
ALTER TABLE purchase_order_items
ADD COLUMN IF NOT EXISTS package_size NUMERIC(12,3) DEFAULT 1.0;

-- Update existing records: try to get package_size from stock_items
UPDATE purchase_order_items poi
SET package_size = COALESCE(
    (SELECT package_size FROM stock_items si WHERE si.id = poi.stock_item_id),
    1.0
)
WHERE poi.package_size IS NULL OR poi.package_size = 1.0;

-- Add comment
COMMENT ON COLUMN purchase_order_items.package_size IS 
'Package size in base unit. Used to calculate packages needed: (quantity / package_size).ceil()';

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ PACKAGE_SIZE COLUMN ADDED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Now PO items can correctly calculate totals:';
    RAISE NOTICE '  packages_needed = (quantity / package_size).ceil()';
    RAISE NOTICE '  total = packages_needed * estimated_price';
    RAISE NOTICE '';
END $$;

