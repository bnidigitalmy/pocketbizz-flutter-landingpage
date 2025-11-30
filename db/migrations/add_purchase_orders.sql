-- Purchase Orders System Migration
-- Creates purchase_orders and purchase_order_items tables

BEGIN;

-- Purchase Orders Table
CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    po_number TEXT NOT NULL,
    supplier_id UUID REFERENCES vendors(id) ON DELETE SET NULL,
    supplier_name TEXT NOT NULL,
    supplier_phone TEXT,
    supplier_email TEXT,
    supplier_address TEXT,
    delivery_address TEXT,
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'received', 'cancelled')),
    notes TEXT,
    expected_delivery_date DATE,
    payment_terms TEXT,
    payment_method TEXT,
    requested_by TEXT,
    discount NUMERIC(12,2) DEFAULT 0,
    tax NUMERIC(12,2) DEFAULT 0,
    shipping_charges NUMERIC(12,2) DEFAULT 0,
    sent_at TIMESTAMPTZ,
    received_at TIMESTAMPTZ,
    expense_id UUID REFERENCES expenses(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_owner ON purchase_orders(business_owner_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(business_owner_id, status);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier ON purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_po_number ON purchase_orders(po_number);

-- Purchase Order Items Table
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    po_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stock_item_id UUID REFERENCES stock_items(id) ON DELETE SET NULL,
    item_name TEXT NOT NULL,
    quantity NUMERIC(12,3) NOT NULL,
    unit TEXT NOT NULL,
    estimated_price NUMERIC(12,2),
    actual_price NUMERIC(12,2),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_po_items_po ON purchase_order_items(po_id);
CREATE INDEX IF NOT EXISTS idx_po_items_stock ON purchase_order_items(stock_item_id);
CREATE INDEX IF NOT EXISTS idx_po_items_owner ON purchase_order_items(business_owner_id);

-- RLS Policies
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;

-- RLS for purchase_orders
CREATE POLICY "Users can view their own purchase orders"
    ON purchase_orders FOR SELECT
    USING (auth.uid() = business_owner_id);

CREATE POLICY "Users can insert their own purchase orders"
    ON purchase_orders FOR INSERT
    WITH CHECK (auth.uid() = business_owner_id);

CREATE POLICY "Users can update their own purchase orders"
    ON purchase_orders FOR UPDATE
    USING (auth.uid() = business_owner_id);

CREATE POLICY "Users can delete their own purchase orders"
    ON purchase_orders FOR DELETE
    USING (auth.uid() = business_owner_id);

-- RLS for purchase_order_items
CREATE POLICY "Users can view their own purchase order items"
    ON purchase_order_items FOR SELECT
    USING (auth.uid() = business_owner_id);

CREATE POLICY "Users can insert their own purchase order items"
    ON purchase_order_items FOR INSERT
    WITH CHECK (auth.uid() = business_owner_id);

CREATE POLICY "Users can update their own purchase order items"
    ON purchase_order_items FOR UPDATE
    USING (auth.uid() = business_owner_id);

CREATE POLICY "Users can delete their own purchase order items"
    ON purchase_order_items FOR DELETE
    USING (auth.uid() = business_owner_id);

-- Function to receive purchase order (update stock & create expense)
CREATE OR REPLACE FUNCTION receive_purchase_order(p_po_id UUID)
RETURNS UUID AS $$
DECLARE
    v_business_owner_id UUID;
    v_total_amount NUMERIC;
    v_expense_id UUID;
    v_po_item RECORD;
BEGIN
    -- Get PO info
    SELECT business_owner_id, total_amount
    INTO v_business_owner_id, v_total_amount
    FROM purchase_orders
    WHERE id = p_po_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase order not found: %', p_po_id;
    END IF;

    -- Update stock for each item
    FOR v_po_item IN
        SELECT stock_item_id, quantity, unit, actual_price, estimated_price
        FROM purchase_order_items
        WHERE po_id = p_po_id AND stock_item_id IS NOT NULL
    LOOP
        -- Use actual_price if available, otherwise estimated_price
        PERFORM record_stock_movement(
            p_stock_item_id := v_po_item.stock_item_id,
            p_movement_type := 'purchase',
            p_quantity_change := v_po_item.quantity,
            p_reason := format('Purchase Order: %s', p_po_id),
            p_reference_id := p_po_id,
            p_reference_type := 'purchase_order',
            p_created_by := auth.uid()
        );
    END LOOP;

    -- Create expense record
    INSERT INTO expenses (
        business_owner_id,
        amount,
        category,
        description,
        expense_date,
        reference_id,
        reference_type
    ) VALUES (
        v_business_owner_id,
        v_total_amount,
        'Purchases',
        format('Purchase Order: %s', p_po_id),
        CURRENT_DATE,
        p_po_id,
        'purchase_order'
    ) RETURNING id INTO v_expense_id;

    -- Update PO status
    UPDATE purchase_orders
    SET 
        status = 'received',
        received_at = NOW(),
        expense_id = v_expense_id,
        updated_at = NOW()
    WHERE id = p_po_id;

    RETURN v_expense_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;



