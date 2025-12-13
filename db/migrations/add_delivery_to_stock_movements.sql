-- Add 'delivery' to production_batch_stock_movements movement_type
-- This allows tracking stock consumption from deliveries

BEGIN;

-- Drop existing constraint
ALTER TABLE production_batch_stock_movements
    DROP CONSTRAINT IF EXISTS production_batch_stock_movements_movement_type_check;

-- Add new constraint with 'delivery' included
ALTER TABLE production_batch_stock_movements
    ADD CONSTRAINT production_batch_stock_movements_movement_type_check
    CHECK (movement_type IN ('sale', 'production', 'adjustment', 'expired', 'damaged', 'delivery'));

-- Update comment
COMMENT ON COLUMN production_batch_stock_movements.movement_type IS 
    'Type of movement: sale, production, adjustment, expired, damaged, delivery';

COMMIT;

