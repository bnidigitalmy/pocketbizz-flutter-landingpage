-- ============================================================================
-- STOCK ITEM BATCHES - Batch Tracking dengan Expiry Dates
-- Support FIFO based on expiry dates untuk raw materials
-- ============================================================================

-- Stock Item Batches Table
CREATE TABLE IF NOT EXISTS stock_item_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
    
    -- Batch Information
    batch_number TEXT,
    quantity NUMERIC(10,2) NOT NULL, -- Total quantity dalam batch ni
    remaining_qty NUMERIC(10,2) NOT NULL, -- Quantity yang masih ada (FIFO)
    
    -- Purchase Information
    purchase_date DATE NOT NULL,
    expiry_date DATE, -- Tarikh luput (optional)
    purchase_price NUMERIC(10,2) NOT NULL, -- Harga untuk batch ni
    package_size NUMERIC(10,2) NOT NULL, -- Saiz package (snapshot)
    
    -- Costing
    cost_per_unit NUMERIC(10,4) NOT NULL, -- Cost per unit untuk batch ni
    
    -- Metadata
    supplier_name TEXT,
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_stock_item_batches_stock_item ON stock_item_batches(stock_item_id);
CREATE INDEX IF NOT EXISTS idx_stock_item_batches_owner ON stock_item_batches(business_owner_id);
CREATE INDEX IF NOT EXISTS idx_stock_item_batches_expiry ON stock_item_batches(expiry_date) WHERE expiry_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_stock_item_batches_remaining ON stock_item_batches(stock_item_id, remaining_qty) WHERE remaining_qty > 0;

-- RLS Policies
ALTER TABLE stock_item_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own stock item batches"
    ON stock_item_batches FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY "Users can insert their own stock item batches"
    ON stock_item_batches FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "Users can update their own stock item batches"
    ON stock_item_batches FOR UPDATE
    USING (business_owner_id = auth.uid())
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "Users can delete their own stock item batches"
    ON stock_item_batches FOR DELETE
    USING (business_owner_id = auth.uid());

-- Trigger untuk auto-update timestamps
CREATE TRIGGER trigger_stock_item_batches_updated_at
    BEFORE UPDATE ON stock_item_batches
    FOR EACH ROW
    EXECUTE FUNCTION update_stock_items_updated_at();

-- ============================================================================
-- FUNCTION: Record Stock Item Batch
-- Creates batch dan optionally records stock movement
-- ============================================================================
CREATE OR REPLACE FUNCTION record_stock_item_batch(
    p_stock_item_id UUID,
    p_quantity NUMERIC,
    p_purchase_date DATE,
    p_purchase_price NUMERIC,
    p_package_size NUMERIC,
    p_expiry_date DATE DEFAULT NULL,
    p_batch_number TEXT DEFAULT NULL,
    p_supplier_name TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_record_movement BOOLEAN DEFAULT TRUE
) RETURNS UUID AS $$
DECLARE
    v_business_owner_id UUID;
    v_cost_per_unit NUMERIC;
    v_batch_id UUID;
BEGIN
    -- Get stock item info
    SELECT business_owner_id, COALESCE(purchase_price / NULLIF(package_size, 0), 0)
    INTO v_business_owner_id, v_cost_per_unit
    FROM stock_items
    WHERE id = p_stock_item_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock item not found: %', p_stock_item_id;
    END IF;
    
    -- Calculate cost per unit untuk batch ni
    v_cost_per_unit := p_purchase_price / NULLIF(p_package_size, 0);
    
    -- Create batch
    INSERT INTO stock_item_batches (
        business_owner_id,
        stock_item_id,
        batch_number,
        quantity,
        remaining_qty,
        purchase_date,
        expiry_date,
        purchase_price,
        package_size,
        cost_per_unit,
        supplier_name,
        notes
    ) VALUES (
        v_business_owner_id,
        p_stock_item_id,
        COALESCE(p_batch_number, 'BATCH-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS')),
        p_quantity,
        p_quantity, -- Initially all remaining
        p_purchase_date,
        p_expiry_date,
        p_purchase_price,
        p_package_size,
        v_cost_per_unit,
        p_supplier_name,
        p_notes
    ) RETURNING id INTO v_batch_id;
    
    -- Optionally record stock movement
    IF p_record_movement THEN
        PERFORM record_stock_movement(
            p_stock_item_id := p_stock_item_id,
            p_movement_type := 'purchase',
            p_quantity_change := p_quantity,
            p_reason := format('Batch purchase: %s', COALESCE(p_batch_number, v_batch_id::TEXT)),
            p_reference_id := v_batch_id,
            p_reference_type := 'stock_item_batch',
            p_created_by := auth.uid()
        );
    END IF;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION record_stock_item_batch IS 'Creates stock item batch dengan optional stock movement recording';

-- ============================================================================
-- FUNCTION: Deduct from Stock Item Batch (FIFO with Expiry)
-- Deducts quantity from oldest batch first, considering expiry dates
-- ============================================================================
CREATE OR REPLACE FUNCTION deduct_from_stock_item_batches(
    p_stock_item_id UUID,
    p_quantity_to_deduct NUMERIC,
    p_reason TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL
) RETURNS TABLE(
    batch_id UUID,
    quantity_deducted NUMERIC,
    cost_per_unit NUMERIC,
    total_cost NUMERIC
) AS $$
DECLARE
    v_remaining_to_deduct NUMERIC := p_quantity_to_deduct;
    v_batch RECORD;
    v_deducted NUMERIC;
BEGIN
    -- Get batches ordered by expiry date (expired first, then oldest), then purchase date
    FOR v_batch IN
        SELECT *
        FROM stock_item_batches
        WHERE stock_item_id = p_stock_item_id
          AND remaining_qty > 0
        ORDER BY 
            CASE WHEN expiry_date IS NOT NULL AND expiry_date < CURRENT_DATE THEN 0 ELSE 1 END, -- Expired first
            COALESCE(expiry_date, '9999-12-31'::DATE), -- Then by expiry date (earliest first)
            purchase_date ASC -- Then by purchase date (oldest first)
    LOOP
        IF v_remaining_to_deduct <= 0 THEN
            EXIT;
        END IF;
        
        -- Calculate how much to deduct from this batch
        v_deducted := LEAST(v_remaining_to_deduct, v_batch.remaining_qty);
        
        -- Update batch remaining quantity
        UPDATE stock_item_batches
        SET 
            remaining_qty = remaining_qty - v_deducted,
            updated_at = NOW()
        WHERE id = v_batch.id;
        
        -- Record stock movement
        PERFORM record_stock_movement(
            p_stock_item_id := p_stock_item_id,
            p_movement_type := 'production_use',
            p_quantity_change := -v_deducted,
            p_reason := COALESCE(p_reason, 'Deducted from batch'),
            p_reference_id := COALESCE(p_reference_id, v_batch.id),
            p_reference_type := COALESCE(p_reference_type, 'stock_item_batch'),
            p_created_by := auth.uid()
        );
        
        -- Return result
        RETURN QUERY SELECT
            v_batch.id,
            v_deducted,
            v_batch.cost_per_unit,
            v_deducted * v_batch.cost_per_unit;
        
        v_remaining_to_deduct := v_remaining_to_deduct - v_deducted;
    END LOOP;
    
    -- If still remaining, raise error
    IF v_remaining_to_deduct > 0 THEN
        RAISE EXCEPTION 'Insufficient stock in batches. Remaining: %', v_remaining_to_deduct;
    END IF;
    
    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION deduct_from_stock_item_batches IS 'Deducts quantity from stock item batches using FIFO with expiry date priority';

-- ============================================================================
-- VIEW: Stock Item Batches Summary
-- Shows summary of batches untuk each stock item
-- ============================================================================
CREATE OR REPLACE VIEW stock_item_batches_summary AS
SELECT 
    sib.stock_item_id,
    si.name as stock_item_name,
    COUNT(*) as total_batches,
    SUM(sib.quantity) as total_quantity,
    SUM(sib.remaining_qty) as total_remaining,
    MIN(sib.expiry_date) as earliest_expiry,
    COUNT(*) FILTER (WHERE sib.expiry_date IS NOT NULL AND sib.expiry_date < CURRENT_DATE) as expired_batches,
    COUNT(*) FILTER (WHERE sib.remaining_qty > 0) as active_batches
FROM stock_item_batches sib
JOIN stock_items si ON si.id = sib.stock_item_id
GROUP BY sib.stock_item_id, si.name;

COMMENT ON VIEW stock_item_batches_summary IS 'Summary of batches untuk each stock item dengan expiry tracking';
