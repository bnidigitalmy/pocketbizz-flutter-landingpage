-- ============================================================================
-- SHOPPING CART / PURCHASE LIST SYSTEM
-- For managing items to purchase from suppliers
-- ============================================================================

BEGIN;

-- Create shopping_cart_items table
CREATE TABLE IF NOT EXISTS shopping_cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
    
    -- Purchase details
    shortage_qty NUMERIC(12,2) NOT NULL CHECK (shortage_qty > 0),
    notes TEXT,
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    
    -- Supplier info (optional)
    preferred_supplier_id UUID REFERENCES vendors(id) ON DELETE SET NULL,
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'ordered', 'received', 'cancelled')),
    ordered_at TIMESTAMP,
    received_at TIMESTAMP,
    
    -- Purchase order reference
    purchase_order_id UUID,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(business_owner_id, stock_item_id, status)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_shopping_cart_user ON shopping_cart_items(business_owner_id, status);
CREATE INDEX IF NOT EXISTS idx_shopping_cart_stock ON shopping_cart_items(stock_item_id);
CREATE INDEX IF NOT EXISTS idx_shopping_cart_priority ON shopping_cart_items(priority) WHERE status = 'pending';

-- Enable RLS
ALTER TABLE shopping_cart_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own cart items"
    ON shopping_cart_items FOR SELECT
    USING (auth.uid() = business_owner_id);

CREATE POLICY "Users can insert own cart items"
    ON shopping_cart_items FOR INSERT
    WITH CHECK (auth.uid() = business_owner_id);

CREATE POLICY "Users can update own cart items"
    ON shopping_cart_items FOR UPDATE
    USING (auth.uid() = business_owner_id);

CREATE POLICY "Users can delete own cart items"
    ON shopping_cart_items FOR DELETE
    USING (auth.uid() = business_owner_id);

-- Function: Bulk add items to cart
CREATE OR REPLACE FUNCTION bulk_add_to_shopping_cart(
    p_items JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_item JSONB;
    v_stock_item_id UUID;
    v_shortage_qty NUMERIC;
    v_notes TEXT;
    v_added INTEGER := 0;
    v_skipped INTEGER := 0;
    v_errors JSONB := '[]'::JSONB;
    v_result JSONB;
BEGIN
    -- Get current user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Process each item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        BEGIN
            v_stock_item_id := (v_item->>'stockItemId')::UUID;
            v_shortage_qty := (v_item->>'shortageQty')::NUMERIC;
            v_notes := v_item->>'notes';

            -- Check if already in cart
            IF EXISTS (
                SELECT 1 FROM shopping_cart_items
                WHERE business_owner_id = v_user_id
                AND stock_item_id = v_stock_item_id
                AND status = 'pending'
            ) THEN
                -- Update existing
                UPDATE shopping_cart_items
                SET shortage_qty = v_shortage_qty,
                    notes = COALESCE(v_notes, notes),
                    updated_at = NOW()
                WHERE business_owner_id = v_user_id
                AND stock_item_id = v_stock_item_id
                AND status = 'pending';
                
                v_skipped := v_skipped + 1;
            ELSE
                -- Insert new
                INSERT INTO shopping_cart_items (
                    business_owner_id,
                    stock_item_id,
                    shortage_qty,
                    notes,
                    status
                ) VALUES (
                    v_user_id,
                    v_stock_item_id,
                    v_shortage_qty,
                    v_notes,
                    'pending'
                );
                
                v_added := v_added + 1;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors || jsonb_build_object(
                'stockItemId', v_stock_item_id,
                'error', SQLERRM
            );
        END;
    END LOOP;

    -- Build result
    v_result := jsonb_build_object(
        'success', true,
        'message', format('%s items added, %s skipped', v_added, v_skipped),
        'results', jsonb_build_object(
            'added', v_added,
            'skipped', v_skipped,
            'errors', v_errors
        )
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SHOPPING CART SYSTEM CREATED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Table: shopping_cart_items';
    RAISE NOTICE '✅ RLS Policies: Enabled';
    RAISE NOTICE '✅ Function: bulk_add_to_shopping_cart';
    RAISE NOTICE '✅ Indexes: Created';
    RAISE NOTICE '';
    RAISE NOTICE '🛒 Shopping cart ready!';
    RAISE NOTICE '';
END $$;

