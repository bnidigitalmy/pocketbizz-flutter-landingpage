-- APPLY ALL C/F MIGRATIONS MANUALLY
-- Run this in Supabase SQL editor if migrations weren't applied

BEGIN;

-- ============================================================================
-- MIGRATION 1: Add carry_forward_status field to consignment_claim_items
-- ============================================================================
ALTER TABLE consignment_claim_items
ADD COLUMN IF NOT EXISTS carry_forward_status TEXT DEFAULT 'none'
CHECK (carry_forward_status IN ('none', 'carry_forward', 'loss'));

CREATE INDEX IF NOT EXISTS idx_claim_items_cf_status
ON consignment_claim_items(claim_id, carry_forward_status);

-- ============================================================================
-- MIGRATION 2: Create carry_forward_items table
-- ============================================================================
CREATE TABLE IF NOT EXISTS carry_forward_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    
    source_claim_id UUID REFERENCES consignment_claims (id) ON DELETE SET NULL,
    source_claim_item_id UUID REFERENCES consignment_claim_items (id) ON DELETE SET NULL,
    source_delivery_id UUID REFERENCES vendor_deliveries (id),
    source_delivery_item_id UUID REFERENCES vendor_delivery_items (id),
    
    product_id UUID REFERENCES products (id),
    product_name TEXT NOT NULL,
    
    quantity_available NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'used', 'expired', 'cancelled')),
    
    original_claim_number TEXT,
    notes TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    used_at TIMESTAMPTZ,
    used_in_claim_id UUID REFERENCES consignment_claims (id),
    
    CONSTRAINT carry_forward_quantity_positive CHECK (quantity_available > 0)
);

CREATE INDEX IF NOT EXISTS idx_cf_items_owner ON carry_forward_items (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_cf_items_vendor ON carry_forward_items (vendor_id);
CREATE INDEX IF NOT EXISTS idx_cf_items_status ON carry_forward_items (status);
CREATE INDEX IF NOT EXISTS idx_cf_items_available ON carry_forward_items (business_owner_id, vendor_id, status) 
    WHERE status = 'available';
CREATE INDEX IF NOT EXISTS idx_cf_items_source_claim ON carry_forward_items (source_claim_id);
CREATE INDEX IF NOT EXISTS idx_cf_items_used_claim ON carry_forward_items (used_in_claim_id);

ALTER TABLE carry_forward_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS carry_forward_items_select_policy ON carry_forward_items;
DROP POLICY IF EXISTS carry_forward_items_insert_policy ON carry_forward_items;
DROP POLICY IF EXISTS carry_forward_items_update_policy ON carry_forward_items;
DROP POLICY IF EXISTS carry_forward_items_delete_policy ON carry_forward_items;

CREATE POLICY carry_forward_items_select_policy ON carry_forward_items 
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY carry_forward_items_insert_policy ON carry_forward_items 
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY carry_forward_items_update_policy ON carry_forward_items 
    FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY carry_forward_items_delete_policy ON carry_forward_items 
    FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- MIGRATION 3: Create trigger function to auto-create C/F items
-- ============================================================================
CREATE OR REPLACE FUNCTION create_carry_forward_items()
RETURNS TRIGGER AS $$
DECLARE
    claim_record RECORD;
    delivery_item_record RECORD;
BEGIN
    -- Get claim info
    SELECT business_owner_id, vendor_id, claim_number
    INTO claim_record
    FROM consignment_claims
    WHERE id = NEW.claim_id;
    
    -- Get delivery item info for product details
    SELECT product_id, product_name, unit_price
    INTO delivery_item_record
    FROM vendor_delivery_items
    WHERE id = NEW.delivery_item_id;
    
    -- If this claim item has unsold quantity and is marked for carry forward
    IF NEW.quantity_unsold > 0 AND NEW.carry_forward_status = 'carry_forward' THEN
        INSERT INTO carry_forward_items (
            business_owner_id,
            vendor_id,
            source_claim_id,
            source_claim_item_id,
            source_delivery_id,
            source_delivery_item_id,
            product_id,
            product_name,
            quantity_available,
            unit_price,
            original_claim_number,
            status
        ) VALUES (
            claim_record.business_owner_id,
            claim_record.vendor_id,
            NEW.claim_id,
            NEW.id,
            NEW.delivery_id,
            NEW.delivery_item_id,
            delivery_item_record.product_id,
            COALESCE(delivery_item_record.product_name, 'Unknown Product'),
            NEW.quantity_unsold,
            NEW.unit_price,
            claim_record.claim_number,
            'available'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MIGRATION 4: Create trigger that calls the function
-- ============================================================================
DROP TRIGGER IF EXISTS trigger_create_carry_forward_items ON consignment_claim_items;

CREATE TRIGGER trigger_create_carry_forward_items
    AFTER INSERT ON consignment_claim_items
    FOR EACH ROW
    WHEN (NEW.quantity_unsold > 0 
          AND NEW.carry_forward_status = 'carry_forward')
EXECUTE FUNCTION create_carry_forward_items();

-- ============================================================================
-- MIGRATION 5: Create view for easier querying
-- ============================================================================
DROP VIEW IF EXISTS available_carry_forward_items;

CREATE OR REPLACE VIEW available_carry_forward_items AS
SELECT 
    cf.id,
    cf.business_owner_id,
    cf.vendor_id,
    cf.source_claim_id,
    cf.source_claim_item_id,
    cf.source_delivery_id,
    cf.source_delivery_item_id,
    cf.product_id,
    cf.product_name,
    cf.quantity_available,
    cf.unit_price,
    cf.original_claim_number,
    cf.created_at,
    v.name as vendor_name,
    p.name as product_name_full,
    p.unit as product_unit
FROM carry_forward_items cf
LEFT JOIN vendors v ON v.id = cf.vendor_id
LEFT JOIN products p ON p.id = cf.product_id
WHERE cf.status = 'available'
    AND cf.quantity_available > 0;

GRANT SELECT ON available_carry_forward_items TO authenticated;

COMMIT;

-- ============================================================================
-- TEST: Insert sample C/F item for testing
-- Replace UUIDs with your actual IDs
-- ============================================================================
-- INSERT INTO carry_forward_items (
--     business_owner_id,
--     vendor_id,
--     product_id,
--     product_name,
--     quantity_available,
--     unit_price,
--     original_claim_number,
--     status
-- ) VALUES (
--     'YOUR_USER_ID',
--     'YOUR_VENDOR_ID',
--     'YOUR_PRODUCT_ID',
--     'Test Product',
--     10.0,
--     50.00,
--     'CLM-2512-0001',
--     'available'
-- );
