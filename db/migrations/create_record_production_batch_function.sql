-- ============================================================================
-- CREATE record_production_batch FUNCTION
-- ============================================================================
-- This function creates a production batch and auto-deducts stock from recipe items
-- It matches the signature expected by ProductionBatchInput model

DROP FUNCTION IF EXISTS record_production_batch CASCADE;

CREATE OR REPLACE FUNCTION record_production_batch(
    p_product_id UUID,
    p_quantity INTEGER,
    p_batch_date DATE DEFAULT CURRENT_DATE,
    p_expiry_date DATE DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_batch_number TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_business_owner_id UUID;
    v_product_name TEXT;
    v_cost_per_unit NUMERIC;
    v_total_cost NUMERIC;
    v_batch_id UUID;
    v_recipe_item RECORD;
    v_quantity_to_deduct NUMERIC;
    v_recipe_id UUID;
    v_stock_cost_per_unit NUMERIC;
    v_recipe_item_id UUID;
BEGIN
    -- Get product info
    SELECT business_owner_id, name, cost_per_unit
    INTO v_business_owner_id, v_product_name, v_cost_per_unit
    FROM products
    WHERE id = p_product_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', p_product_id;
    END IF;
    
    -- Get active recipe for this product
    SELECT id INTO v_recipe_id
    FROM recipes
    WHERE product_id = p_product_id
      AND is_active = true
    LIMIT 1;
    
    IF v_recipe_id IS NULL THEN
        RAISE EXCEPTION 'No active recipe found for product: %', p_product_id;
    END IF;
    
    -- Calculate total cost
    v_total_cost := COALESCE(v_cost_per_unit, 0) * p_quantity;
    
    -- Create production batch
    INSERT INTO production_batches (
        business_owner_id, 
        product_id, 
        batch_number, 
        product_name,
        quantity, 
        remaining_qty, 
        batch_date, 
        expiry_date,
        total_cost, 
        cost_per_unit, 
        notes, 
        created_at
    ) VALUES (
        v_business_owner_id, 
        p_product_id, 
        COALESCE(p_batch_number, 'BATCH-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS')), 
        v_product_name,
        p_quantity, 
        p_quantity, 
        p_batch_date, 
        p_expiry_date,
        v_total_cost, 
        v_cost_per_unit, 
        p_notes, 
        NOW()
    ) RETURNING id INTO v_batch_id;
    
    -- Deduct stock from recipe items (using new structure with recipes table)
    FOR v_recipe_item IN
        SELECT 
            ri.stock_item_id, 
            ri.quantity_needed,
            ri.usage_unit,
            si.unit as stock_unit,
            si.current_quantity
        FROM recipe_items ri
        JOIN stock_items si ON si.id = ri.stock_item_id
        WHERE ri.recipe_id = v_recipe_id
    LOOP
        -- Calculate quantity to deduct (convert units if needed)
        v_quantity_to_deduct := v_recipe_item.quantity_needed * p_quantity;
        
        -- Record stock movement (auto-deduct)
        PERFORM record_stock_movement(
            p_stock_item_id := v_recipe_item.stock_item_id,
            p_movement_type := 'production_use',
            p_quantity_change := -v_quantity_to_deduct,
            p_reason := format('Production: %s (Batch: %s)', v_product_name, v_batch_id),
            p_reference_id := v_batch_id,
            p_reference_type := 'production_batch',
            p_created_by := auth.uid()
        );
        
        -- Get stock item cost per unit
        SELECT 
            COALESCE(purchase_price / NULLIF(package_size, 0), 0)
        INTO v_stock_cost_per_unit
        FROM stock_items
        WHERE id = v_recipe_item.stock_item_id;
        
        -- Get recipe item ID
        SELECT id INTO v_recipe_item_id
        FROM recipe_items
        WHERE recipe_id = v_recipe_id
          AND stock_item_id = v_recipe_item.stock_item_id
        LIMIT 1;
        
        -- Record ingredient usage for audit
        INSERT INTO production_ingredient_usage (
            business_owner_id,
            production_batch_id,
            stock_item_id,
            recipe_item_id,
            quantity_used,
            unit,
            cost_per_unit,
            total_cost
        ) VALUES (
            v_business_owner_id,
            v_batch_id,
            v_recipe_item.stock_item_id,
            v_recipe_item_id,
            v_quantity_to_deduct,
            v_recipe_item.usage_unit,
            COALESCE(v_stock_cost_per_unit, 0),
            v_quantity_to_deduct * COALESCE(v_stock_cost_per_unit, 0)
        );
    END LOOP;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION record_production_batch IS 'Creates production batch and auto-deducts stock from recipe items in one transaction';

