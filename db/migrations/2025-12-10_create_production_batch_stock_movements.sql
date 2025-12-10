-- Production Batch Stock Movements Tracking
-- Tracks where and when stock from production batches is used

CREATE TABLE IF NOT EXISTS production_batch_stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    batch_id UUID NOT NULL REFERENCES production_batches (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id),
    
    -- Movement details
    movement_type TEXT NOT NULL CHECK (movement_type IN ('sale', 'production', 'adjustment', 'expired', 'damaged')),
    quantity NUMERIC(12,3) NOT NULL,
    remaining_after_movement NUMERIC(12,3) NOT NULL,
    
    -- Reference to source (e.g., sale_id, production_batch_id)
    reference_id UUID, -- Can reference sales.id, production_batches.id, etc.
    reference_type TEXT, -- 'sale', 'production', 'adjustment', etc.
    
    -- Additional info
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_batch_movements_batch ON production_batch_stock_movements (batch_id);
CREATE INDEX IF NOT EXISTS idx_batch_movements_product ON production_batch_stock_movements (product_id);
CREATE INDEX IF NOT EXISTS idx_batch_movements_owner ON production_batch_stock_movements (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_batch_movements_reference ON production_batch_stock_movements (reference_id, reference_type);
CREATE INDEX IF NOT EXISTS idx_batch_movements_created ON production_batch_stock_movements (created_at DESC);

-- Enable RLS
ALTER TABLE production_batch_stock_movements ENABLE ROW LEVEL SECURITY;

-- RLS Policies (Drop if exists first to avoid conflicts)
DROP POLICY IF EXISTS batch_movements_select_policy ON production_batch_stock_movements;
DROP POLICY IF EXISTS batch_movements_insert_policy ON production_batch_stock_movements;

CREATE POLICY batch_movements_select_policy ON production_batch_stock_movements
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY batch_movements_insert_policy ON production_batch_stock_movements
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

-- Comments
COMMENT ON TABLE production_batch_stock_movements IS 'Tracks all stock movements (usage) for production batches - shows where stock goes';
COMMENT ON COLUMN production_batch_stock_movements.movement_type IS 'Type of movement: sale, production, adjustment, expired, damaged';
COMMENT ON COLUMN production_batch_stock_movements.reference_id IS 'ID of the related record (e.g., sale_id, production_batch_id)';
COMMENT ON COLUMN production_batch_stock_movements.reference_type IS 'Type of reference record (e.g., sale, production)';

