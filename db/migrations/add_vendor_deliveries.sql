-- ============================================================================
-- VENDOR DELIVERIES SYSTEM
-- Tables for managing deliveries to vendors/resellers
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: DROP EXISTING TABLES (if any) - Safe installation
-- ============================================================================
DROP TABLE IF EXISTS vendor_delivery_items CASCADE;
DROP TABLE IF EXISTS vendor_deliveries CASCADE;

-- Drop existing functions
DROP FUNCTION IF EXISTS generate_delivery_invoice_number();

-- ============================================================================
-- STEP 2: CREATE VENDOR_DELIVERIES TABLE
-- ============================================================================
CREATE TABLE vendor_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    
    -- Vendor Information
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    vendor_name TEXT NOT NULL, -- Denormalized for performance
    
    -- Delivery Information
    delivery_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'delivered' CHECK (status IN ('delivered', 'pending', 'claimed', 'rejected')),
    payment_status TEXT CHECK (payment_status IN ('pending', 'partial', 'settled')),
    
    -- Financial
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    invoice_number TEXT UNIQUE, -- Auto-generated
    
    -- Notes
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_deliveries_total_positive CHECK (total_amount >= 0)
);

CREATE INDEX idx_vendor_deliveries_business_owner ON vendor_deliveries (business_owner_id);
CREATE INDEX idx_vendor_deliveries_vendor ON vendor_deliveries (vendor_id);
CREATE INDEX idx_vendor_deliveries_date ON vendor_deliveries (delivery_date DESC);
CREATE INDEX idx_vendor_deliveries_status ON vendor_deliveries (status);
CREATE INDEX idx_vendor_deliveries_payment_status ON vendor_deliveries (payment_status);
CREATE INDEX idx_vendor_deliveries_invoice_number ON vendor_deliveries (invoice_number);

-- Enable RLS
ALTER TABLE vendor_deliveries ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY vendor_deliveries_select_policy ON vendor_deliveries 
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY vendor_deliveries_insert_policy ON vendor_deliveries 
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY vendor_deliveries_update_policy ON vendor_deliveries 
    FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY vendor_deliveries_delete_policy ON vendor_deliveries 
    FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 3: CREATE VENDOR_DELIVERY_ITEMS TABLE
-- ============================================================================
CREATE TABLE vendor_delivery_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delivery_id UUID NOT NULL REFERENCES vendor_deliveries (id) ON DELETE CASCADE,
    
    -- Product Information
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    product_name TEXT NOT NULL, -- Denormalized for performance
    
    -- Quantity and Pricing
    quantity NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total_price NUMERIC(12,2) NOT NULL,
    retail_price NUMERIC(12,2), -- Original retail price before commission
    
    -- Rejection Tracking
    rejected_qty NUMERIC(12,3) DEFAULT 0,
    rejection_reason TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_delivery_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT vendor_delivery_items_price_positive CHECK (unit_price >= 0 AND total_price >= 0),
    CONSTRAINT vendor_delivery_items_rejected_valid CHECK (rejected_qty >= 0 AND rejected_qty <= quantity)
);

CREATE INDEX idx_vendor_delivery_items_delivery ON vendor_delivery_items (delivery_id);
CREATE INDEX idx_vendor_delivery_items_product ON vendor_delivery_items (product_id);

-- Enable RLS
ALTER TABLE vendor_delivery_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies (inherit from parent delivery)
CREATE POLICY vendor_delivery_items_select_policy ON vendor_delivery_items 
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendor_deliveries 
            WHERE vendor_deliveries.id = vendor_delivery_items.delivery_id 
            AND vendor_deliveries.business_owner_id = auth.uid()
        )
    );

CREATE POLICY vendor_delivery_items_insert_policy ON vendor_delivery_items 
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM vendor_deliveries 
            WHERE vendor_deliveries.id = vendor_delivery_items.delivery_id 
            AND vendor_deliveries.business_owner_id = auth.uid()
        )
    );

CREATE POLICY vendor_delivery_items_update_policy ON vendor_delivery_items 
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM vendor_deliveries 
            WHERE vendor_deliveries.id = vendor_delivery_items.delivery_id 
            AND vendor_deliveries.business_owner_id = auth.uid()
        )
    );

CREATE POLICY vendor_delivery_items_delete_policy ON vendor_delivery_items 
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM vendor_deliveries 
            WHERE vendor_deliveries.id = vendor_delivery_items.delivery_id 
            AND vendor_deliveries.business_owner_id = auth.uid()
        )
    );

-- ============================================================================
-- STEP 4: CREATE FUNCTION TO GENERATE INVOICE NUMBER
-- ============================================================================
CREATE OR REPLACE FUNCTION generate_delivery_invoice_number()
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT := 'DEL';
    v_year TEXT := TO_CHAR(NOW(), 'YY');
    v_month TEXT := TO_CHAR(NOW(), 'MM');
    v_seq_num INTEGER;
    v_invoice_number TEXT;
BEGIN
    -- Get next sequence number for this month
    SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM vendor_deliveries
    WHERE invoice_number LIKE v_prefix || v_year || v_month || '%';
    
    -- Format: DEL-YYMM-0001
    v_invoice_number := v_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
    
    RETURN v_invoice_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 5: CREATE TRIGGER TO AUTO-GENERATE INVOICE NUMBER
-- ============================================================================
CREATE OR REPLACE FUNCTION set_delivery_invoice_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.invoice_number IS NULL OR NEW.invoice_number = '' THEN
        NEW.invoice_number := generate_delivery_invoice_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_delivery_invoice_number
    BEFORE INSERT ON vendor_deliveries
    FOR EACH ROW
    EXECUTE FUNCTION set_delivery_invoice_number();

-- ============================================================================
-- STEP 6: CREATE TRIGGER TO UPDATE UPDATED_AT TIMESTAMP
-- ============================================================================
CREATE OR REPLACE FUNCTION update_vendor_deliveries_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_vendor_deliveries_updated_at
    BEFORE UPDATE ON vendor_deliveries
    FOR EACH ROW
    EXECUTE FUNCTION update_vendor_deliveries_updated_at();

CREATE TRIGGER trigger_update_vendor_delivery_items_updated_at
    BEFORE UPDATE ON vendor_delivery_items
    FOR EACH ROW
    EXECUTE FUNCTION update_vendor_deliveries_updated_at();

COMMIT;

-- ============================================================================
-- NOTES:
-- 1. Delivery status: delivered, pending, claimed, rejected
-- 2. Payment status: pending, partial, settled
-- 3. Invoice number auto-generated on insert (format: DEL-YYMM-0001)
-- 4. Rejection tracking allows partial rejection with reason
-- 5. Retail price stored for commission calculation reference
-- ============================================================================

