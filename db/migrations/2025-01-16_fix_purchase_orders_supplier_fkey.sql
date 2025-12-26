-- ============================================================================
-- FIX PURCHASE ORDERS SUPPLIER FOREIGN KEY CONSTRAINT
-- ============================================================================
-- Problem: purchase_orders.supplier_id references vendors(id) but should
--          reference suppliers(id) since suppliers and vendors are separate entities
--
-- Solution: Drop old foreign key constraint and create new one referencing suppliers table
-- ============================================================================

BEGIN;

-- Step 1: Drop the old foreign key constraint if it exists
DO $$
BEGIN
    -- Drop the constraint if it exists
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'purchase_orders_supplier_id_fkey'
        AND table_name = 'purchase_orders'
    ) THEN
        ALTER TABLE purchase_orders 
        DROP CONSTRAINT purchase_orders_supplier_id_fkey;
        
        RAISE NOTICE '✅ Dropped old foreign key constraint purchase_orders_supplier_id_fkey';
    ELSE
        RAISE NOTICE '⚠️  Constraint purchase_orders_supplier_id_fkey does not exist, skipping drop';
    END IF;
END $$;

-- Step 2: Update any existing supplier_id values that reference vendors
-- to NULL (since we can't automatically convert vendor IDs to supplier IDs)
-- Users will need to manually reassign suppliers if needed
DO $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Count how many rows will be affected
    SELECT COUNT(*) INTO affected_count
    FROM purchase_orders
    WHERE supplier_id IS NOT NULL
    AND supplier_id NOT IN (SELECT id FROM suppliers);
    
    IF affected_count > 0 THEN
        -- Set supplier_id to NULL for rows that reference vendors
        UPDATE purchase_orders
        SET supplier_id = NULL
        WHERE supplier_id IS NOT NULL
        AND supplier_id NOT IN (SELECT id FROM suppliers);
        
        RAISE NOTICE '⚠️  Set % purchase order(s) supplier_id to NULL (were referencing vendors)', affected_count;
    ELSE
        RAISE NOTICE '✅ No purchase orders need supplier_id updates';
    END IF;
END $$;

-- Step 3: Create new foreign key constraint referencing suppliers table
DO $$
BEGIN
    ALTER TABLE purchase_orders
    ADD CONSTRAINT purchase_orders_supplier_id_fkey
    FOREIGN KEY (supplier_id)
    REFERENCES suppliers(id)
    ON DELETE SET NULL;
    
    RAISE NOTICE '✅ Created new foreign key constraint purchase_orders_supplier_id_fkey referencing suppliers table';
EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE '⚠️  Constraint purchase_orders_supplier_id_fkey already exists';
END $$;

COMMIT;

