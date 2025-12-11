-- Fix Unit Conversion in record_production_batch Function
-- This ensures stock check and deduction use correct unit conversion

-- Helper function for unit conversion (simplified version matching Flutter logic)
CREATE OR REPLACE FUNCTION convert_unit(
    p_quantity NUMERIC,
    p_from_unit TEXT,
    p_to_unit TEXT
) RETURNS NUMERIC AS $$
DECLARE
    v_from TEXT := LOWER(TRIM(p_from_unit));
    v_to TEXT := LOWER(TRIM(p_to_unit));
    v_factor NUMERIC;
BEGIN
    -- If same unit, no conversion needed
    IF v_from = v_to THEN
        RETURN p_quantity;
    END IF;

    -- Weight conversions
    IF v_from = 'kg' AND v_to = 'gram' THEN
        RETURN p_quantity * 1000;
    ELSIF v_from = 'kg' AND v_to = 'g' THEN
        RETURN p_quantity * 1000;
    ELSIF v_from = 'gram' AND v_to = 'kg' THEN
        RETURN p_quantity * 0.001;
    ELSIF v_from = 'g' AND v_to = 'kg' THEN
        RETURN p_quantity * 0.001;
    ELSIF v_from = 'gram' AND v_to = 'g' THEN
        RETURN p_quantity;
    ELSIF v_from = 'g' AND v_to = 'gram' THEN
        RETURN p_quantity;
    END IF;

    -- Volume conversions
    IF v_from = 'liter' AND v_to = 'ml' THEN
        RETURN p_quantity * 1000;
    ELSIF v_from = 'l' AND v_to = 'ml' THEN
        RETURN p_quantity * 1000;
    ELSIF v_from = 'ml' AND v_to = 'liter' THEN
        RETURN p_quantity * 0.001;
    ELSIF v_from = 'ml' AND v_to = 'l' THEN
        RETURN p_quantity * 0.001;
    ELSIF v_from = 'liter' AND v_to = 'tbsp' THEN
        RETURN p_quantity * 66.67;
    ELSIF v_from = 'l' AND v_to = 'tbsp' THEN
        RETURN p_quantity * 66.67;
    ELSIF v_from = 'ml' AND v_to = 'tbsp' THEN
        RETURN p_quantity * 0.0667;
    ELSIF v_from = 'tbsp' AND v_to = 'ml' THEN
        RETURN p_quantity * 15.0;
    ELSIF v_from = 'tbsp' AND v_to = 'liter' THEN
        RETURN p_quantity * 0.015;
    ELSIF v_from = 'tbsp' AND v_to = 'l' THEN
        RETURN p_quantity * 0.015;
    ELSIF v_from = 'tsp' AND v_to = 'ml' THEN
        RETURN p_quantity * 5.0;
    ELSIF v_from = 'ml' AND v_to = 'tsp' THEN
        RETURN p_quantity * 0.2;
    ELSIF v_from = 'tsp' AND v_to = 'tbsp' THEN
        RETURN p_quantity * 0.333;
    ELSIF v_from = 'tbsp' AND v_to = 'tsp' THEN
        RETURN p_quantity * 3.0;
    END IF;

    -- Count conversions
    IF v_from = 'dozen' AND v_to = 'pcs' THEN
        RETURN p_quantity * 12;
    ELSIF v_from = 'dozen' AND v_to = 'pieces' THEN
        RETURN p_quantity * 12;
    ELSIF v_from = 'pcs' AND v_to = 'dozen' THEN
        RETURN p_quantity * 0.0833;
    ELSIF v_from = 'pieces' AND v_to = 'dozen' THEN
        RETURN p_quantity * 0.0833;
    ELSIF v_from = 'pcs' AND v_to = 'pieces' THEN
        RETURN p_quantity;
    ELSIF v_from = 'pieces' AND v_to = 'pcs' THEN
        RETURN p_quantity;
    END IF;

    -- If conversion not found, return original (with warning in logs)
    -- This allows the system to continue but may cause issues
    RAISE WARNING 'Unit conversion not found: % to %. Returning original quantity.', p_from_unit, p_to_unit;
    RETURN p_quantity;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Update record_production_batch to use unit conversion
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
    v_quantity_to_deduct_converted NUMERIC;
    v_recipe_id UUID;
    v_stock_cost_per_unit NUMERIC;
    v_recipe_item_id UUID;
    v_units_per_batch INTEGER;
    v_batches_needed NUMERIC;
BEGIN
    -- Get product info including units_per_batch
    SELECT business_owner_id, name, cost_per_unit, COALESCE(units_per_batch, 1)
    INTO v_business_owner_id, v_product_name, v_cost_per_unit, v_units_per_batch
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
    
    -- Calculate number of batches needed
    -- p_quantity is total units, so divide by units_per_batch to get batches
    v_batches_needed := p_quantity::NUMERIC / NULLIF(v_units_per_batch, 0);
    IF v_batches_needed IS NULL OR v_batches_needed <= 0 THEN
        v_batches_needed := 1;
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
    -- FIRST PASS: Check if all ingredients have sufficient stock (WITH UNIT CONVERSION)
    FOR v_recipe_item IN
        SELECT 
            ri.stock_item_id, 
            ri.quantity_needed,
            ri.usage_unit,
            si.unit as stock_unit,
            si.current_quantity,
            si.name as stock_item_name
        FROM recipe_items ri
        JOIN stock_items si ON si.id = ri.stock_item_id
        WHERE ri.recipe_id = v_recipe_id
    LOOP
        -- Calculate total quantity needed (in usage_unit)
        -- quantity_needed is per batch, so multiply by batches_needed
        v_quantity_to_deduct := v_recipe_item.quantity_needed * v_batches_needed;
        
        -- Convert to stock_unit for comparison
        v_quantity_to_deduct_converted := convert_unit(
            v_quantity_to_deduct,
            v_recipe_item.usage_unit,
            v_recipe_item.stock_unit
        );
        
        -- Check if stock is sufficient BEFORE deducting (using converted quantity)
        IF v_recipe_item.current_quantity < v_quantity_to_deduct_converted THEN
            RAISE EXCEPTION 'Stok tidak mencukupi. Stok semasa: %, Kuantiti diperlukan: %', 
                v_recipe_item.current_quantity,
                v_quantity_to_deduct_converted;
        END IF;
    END LOOP;
    
    -- SECOND PASS: If all checks passed, proceed with deduction (WITH UNIT CONVERSION)
    FOR v_recipe_item IN
        SELECT 
            ri.stock_item_id, 
            ri.quantity_needed,
            ri.usage_unit,
            si.unit as stock_unit,
            si.current_quantity,
            si.name as stock_item_name
        FROM recipe_items ri
        JOIN stock_items si ON si.id = ri.stock_item_id
        WHERE ri.recipe_id = v_recipe_id
    LOOP
        -- Calculate total quantity needed (in usage_unit)
        -- quantity_needed is per batch, so multiply by batches_needed
        v_quantity_to_deduct := v_recipe_item.quantity_needed * v_batches_needed;
        
        -- Convert to stock_unit for deduction
        v_quantity_to_deduct_converted := convert_unit(
            v_quantity_to_deduct,
            v_recipe_item.usage_unit,
            v_recipe_item.stock_unit
        );
        
        -- Record stock movement (auto-deduct) - using converted quantity in stock_unit
        PERFORM record_stock_movement(
            p_stock_item_id := v_recipe_item.stock_item_id,
            p_movement_type := 'production_use',
            p_quantity_change := -v_quantity_to_deduct_converted,
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
        
        -- Record ingredient usage for audit (in usage_unit, not converted)
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
            v_quantity_to_deduct_converted * COALESCE(v_stock_cost_per_unit, 0)
        );
    END LOOP;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION record_production_batch IS 'Creates production batch and auto-deducts stock from recipe items with proper unit conversion';

