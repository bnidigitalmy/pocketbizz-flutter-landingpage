-- ============================================================================
-- ADD PRODUCT COSTING FIELDS
-- Add fields for production costing and recipe management
-- ============================================================================

BEGIN;

-- Add new columns to products table
DO $$
BEGIN
    -- Units per batch (how many units produced per recipe)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'units_per_batch'
    ) THEN
        ALTER TABLE products ADD COLUMN units_per_batch INTEGER DEFAULT 1;
    END IF;

    -- Labour cost per batch
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'labour_cost'
    ) THEN
        ALTER TABLE products ADD COLUMN labour_cost NUMERIC(12,2) DEFAULT 0;
    END IF;

    -- Other costs per batch (gas, electric, etc)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'other_costs'
    ) THEN
        ALTER TABLE products ADD COLUMN other_costs NUMERIC(12,2) DEFAULT 0;
    END IF;

    -- Packaging cost PER UNIT
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'packaging_cost'
    ) THEN
        ALTER TABLE products ADD COLUMN packaging_cost NUMERIC(12,2) DEFAULT 0;
    END IF;

    -- Calculated fields (stored for reference, can be recalculated)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'materials_cost'
    ) THEN
        ALTER TABLE products ADD COLUMN materials_cost NUMERIC(12,2) DEFAULT 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'total_cost_per_batch'
    ) THEN
        ALTER TABLE products ADD COLUMN total_cost_per_batch NUMERIC(12,2) DEFAULT 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'cost_per_unit'
    ) THEN
        ALTER TABLE products ADD COLUMN cost_per_unit NUMERIC(12,2) DEFAULT 0;
    END IF;
END $$;

COMMIT;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ PRODUCT COSTING FIELDS ADDED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Added: units_per_batch';
    RAISE NOTICE '✅ Added: labour_cost';
    RAISE NOTICE '✅ Added: other_costs';
    RAISE NOTICE '✅ Added: packaging_cost';
    RAISE NOTICE '✅ Added: materials_cost';
    RAISE NOTICE '✅ Added: total_cost_per_batch';
    RAISE NOTICE '✅ Added: cost_per_unit';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Product costing ready!';
    RAISE NOTICE '';
END $$;

