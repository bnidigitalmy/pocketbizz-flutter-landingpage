-- Enable Negative Stock Prevention
-- Prevents stock from going negative for production/waste/return movements
-- Allows negative for purchase/replenish (shouldn't happen but just in case)

CREATE OR REPLACE FUNCTION record_stock_movement(
    p_stock_item_id UUID,
    p_movement_type stock_movement_type,
    p_quantity_change NUMERIC,
    p_reason TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_business_owner_id UUID;
    v_quantity_before NUMERIC;
    v_quantity_after NUMERIC;
    v_movement_id UUID;
    v_current_version INTEGER;
BEGIN
    -- Get current stock info with row lock (prevent concurrent modifications)
    SELECT business_owner_id, current_quantity, version
    INTO v_business_owner_id, v_quantity_before, v_current_version
    FROM stock_items
    WHERE id = p_stock_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock item not found: %', p_stock_item_id;
    END IF;

    -- Calculate new quantity
    v_quantity_after := v_quantity_before + p_quantity_change;

    -- Prevent negative stock for movements that REDUCE stock
    -- Allow negative for purchase/replenish (shouldn't happen, but just in case)
    IF v_quantity_after < 0 AND p_quantity_change < 0 THEN
        -- This is a stock reduction (production_use, waste, return, adjust, etc.)
        RAISE EXCEPTION 'Stok tidak mencukupi. Stok semasa: %, Kuantiti diperlukan: %', 
            v_quantity_before, ABS(p_quantity_change);
    END IF;

    -- Update stock item quantity & version (optimistic locking)
    UPDATE stock_items
    SET 
        current_quantity = v_quantity_after,
        version = version + 1,
        updated_at = NOW()
    WHERE id = p_stock_item_id
      AND version = v_current_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock item was modified by another transaction. Please retry.';
    END IF;

    -- Record the movement in audit trail
    INSERT INTO stock_movements (
        business_owner_id,
        stock_item_id,
        movement_type,
        quantity_before,
        quantity_change,
        quantity_after,
        reason,
        reference_id,
        reference_type,
        created_by,
        created_at
    ) VALUES (
        v_business_owner_id,
        p_stock_item_id,
        p_movement_type,
        v_quantity_before,
        p_quantity_change,
        v_quantity_after,
        p_reason,
        p_reference_id,
        p_reference_type,
        COALESCE(p_created_by, auth.uid()),
        NOW()
    ) RETURNING id INTO v_movement_id;

    RETURN v_movement_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

