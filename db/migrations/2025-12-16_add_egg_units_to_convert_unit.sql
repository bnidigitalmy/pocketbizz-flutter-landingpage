-- ============================================================================
-- ADD EGG UNITS (BIJI/PAPAN/SARANG/TRAY) TO convert_unit()
-- Ensures DB unit conversion matches Flutter for baking workflows.
-- Notes:
-- - "biji" is treated as 1 piece
-- - "papan/sarang/tray" is treated as 30 pieces (common egg tray)
-- ============================================================================

CREATE OR REPLACE FUNCTION convert_unit(
    p_quantity NUMERIC,
    p_from_unit TEXT,
    p_to_unit TEXT
) RETURNS NUMERIC AS $$
DECLARE
    v_from TEXT := LOWER(TRIM(p_from_unit));
    v_to TEXT := LOWER(TRIM(p_to_unit));
BEGIN
    -- If same unit, no conversion needed
    IF v_from = v_to THEN
        RETURN p_quantity;
    END IF;

    -- =========================================================================
    -- WEIGHT CONVERSIONS (Metric & Imperial)
    -- =========================================================================

    -- kg conversions
    IF v_from = 'kg' OR v_from = 'kilogram' THEN
        IF v_to = 'gram' OR v_to = 'g' THEN RETURN p_quantity * 1000;
        ELSIF v_to = 'mg' THEN RETURN p_quantity * 1000000;
        ELSIF v_to = 'oz' THEN RETURN p_quantity * 35.274;
        ELSIF v_to = 'lb' OR v_to = 'pound' THEN RETURN p_quantity * 2.20462;
        END IF;
    END IF;

    -- gram/g conversions
    IF v_from = 'gram' OR v_from = 'g' THEN
        IF v_to = 'kg' OR v_to = 'kilogram' THEN RETURN p_quantity * 0.001;
        ELSIF v_to = 'mg' THEN RETURN p_quantity * 1000;
        ELSIF v_to = 'oz' THEN RETURN p_quantity * 0.035274;
        ELSIF v_to = 'lb' OR v_to = 'pound' THEN RETURN p_quantity * 0.00220462;
        END IF;
    END IF;

    -- mg conversions
    IF v_from = 'mg' THEN
        IF v_to = 'kg' OR v_to = 'kilogram' THEN RETURN p_quantity * 0.000001;
        ELSIF v_to = 'gram' OR v_to = 'g' THEN RETURN p_quantity * 0.001;
        ELSIF v_to = 'oz' THEN RETURN p_quantity * 0.000035274;
        ELSIF v_to = 'lb' OR v_to = 'pound' THEN RETURN p_quantity * 0.00000220462;
        END IF;
    END IF;

    -- oz conversions
    IF v_from = 'oz' THEN
        IF v_to = 'kg' OR v_to = 'kilogram' THEN RETURN p_quantity * 0.0283495;
        ELSIF v_to = 'gram' OR v_to = 'g' THEN RETURN p_quantity * 28.3495;
        ELSIF v_to = 'mg' THEN RETURN p_quantity * 28349.5;
        ELSIF v_to = 'lb' OR v_to = 'pound' THEN RETURN p_quantity * 0.0625;
        END IF;
    END IF;

    -- lb/pound conversions
    IF v_from = 'lb' OR v_from = 'pound' THEN
        IF v_to = 'kg' OR v_to = 'kilogram' THEN RETURN p_quantity * 0.453592;
        ELSIF v_to = 'gram' OR v_to = 'g' THEN RETURN p_quantity * 453.592;
        ELSIF v_to = 'mg' THEN RETURN p_quantity * 453592.0;
        ELSIF v_to = 'oz' THEN RETURN p_quantity * 16.0;
        END IF;
    END IF;

    -- =========================================================================
    -- VOLUME CONVERSIONS (Metric, Cooking, Imperial)
    -- =========================================================================

    -- liter/l conversions
    IF v_from = 'liter' OR v_from = 'l' THEN
        IF v_to = 'ml' OR v_to = 'milliliter' THEN RETURN p_quantity * 1000;
        ELSIF v_to = 'cup' THEN RETURN p_quantity * 4.22675;
        ELSIF v_to = 'tbsp' THEN RETURN p_quantity * 66.67;
        ELSIF v_to = 'tsp' THEN RETURN p_quantity * 200.0;
        ELSIF v_to = 'floz' THEN RETURN p_quantity * 33.814;
        ELSIF v_to = 'pint' THEN RETURN p_quantity * 2.11338;
        ELSIF v_to = 'quart' THEN RETURN p_quantity * 1.05669;
        ELSIF v_to = 'gallon' THEN RETURN p_quantity * 0.264172;
        END IF;
    END IF;

    -- ml/milliliter conversions
    IF v_from = 'ml' OR v_from = 'milliliter' THEN
        IF v_to = 'liter' OR v_to = 'l' THEN RETURN p_quantity * 0.001;
        ELSIF v_to = 'cup' THEN RETURN p_quantity * 0.00422675;
        ELSIF v_to = 'tbsp' THEN RETURN p_quantity * 0.0667;
        ELSIF v_to = 'tsp' THEN RETURN p_quantity * 0.2;
        ELSIF v_to = 'floz' THEN RETURN p_quantity * 0.033814;
        ELSIF v_to = 'pint' THEN RETURN p_quantity * 0.00211338;
        ELSIF v_to = 'quart' THEN RETURN p_quantity * 0.00105669;
        ELSIF v_to = 'gallon' THEN RETURN p_quantity * 0.000264172;
        END IF;
    END IF;

    -- cup conversions
    IF v_from = 'cup' THEN
        IF v_to = 'liter' OR v_to = 'l' THEN RETURN p_quantity * 0.236588;
        ELSIF v_to = 'ml' OR v_to = 'milliliter' THEN RETURN p_quantity * 236.588;
        ELSIF v_to = 'tbsp' THEN RETURN p_quantity * 16.0;
        ELSIF v_to = 'tsp' THEN RETURN p_quantity * 48.0;
        ELSIF v_to = 'floz' THEN RETURN p_quantity * 8.0;
        ELSIF v_to = 'pint' THEN RETURN p_quantity * 0.5;
        ELSIF v_to = 'quart' THEN RETURN p_quantity * 0.25;
        ELSIF v_to = 'gallon' THEN RETURN p_quantity * 0.0625;
        END IF;
    END IF;

    -- tbsp conversions
    IF v_from = 'tbsp' THEN
        IF v_to = 'liter' OR v_to = 'l' THEN RETURN p_quantity * 0.0147868;
        ELSIF v_to = 'ml' OR v_to = 'milliliter' THEN RETURN p_quantity * 14.7868;
        ELSIF v_to = 'cup' THEN RETURN p_quantity * 0.0625;
        ELSIF v_to = 'tsp' THEN RETURN p_quantity * 3.0;
        ELSIF v_to = 'floz' THEN RETURN p_quantity * 0.5;
        ELSIF v_to = 'pint' THEN RETURN p_quantity * 0.03125;
        ELSIF v_to = 'quart' THEN RETURN p_quantity * 0.015625;
        ELSIF v_to = 'gallon' THEN RETURN p_quantity * 0.00390625;
        END IF;
    END IF;

    -- tsp conversions
    IF v_from = 'tsp' THEN
        IF v_to = 'liter' OR v_to = 'l' THEN RETURN p_quantity * 0.00492892;
        ELSIF v_to = 'ml' OR v_to = 'milliliter' THEN RETURN p_quantity * 4.92892;
        ELSIF v_to = 'cup' THEN RETURN p_quantity * 0.0208333;
        ELSIF v_to = 'tbsp' THEN RETURN p_quantity * 0.333333;
        ELSIF v_to = 'floz' THEN RETURN p_quantity * 0.166667;
        ELSIF v_to = 'pint' THEN RETURN p_quantity * 0.0104167;
        ELSIF v_to = 'quart' THEN RETURN p_quantity * 0.00520833;
        ELSIF v_to = 'gallon' THEN RETURN p_quantity * 0.00130208;
        END IF;
    END IF;

    -- floz conversions
    IF v_from = 'floz' THEN
        IF v_to = 'liter' OR v_to = 'l' THEN RETURN p_quantity * 0.0295735;
        ELSIF v_to = 'ml' OR v_to = 'milliliter' THEN RETURN p_quantity * 29.5735;
        ELSIF v_to = 'cup' THEN RETURN p_quantity * 0.125;
        ELSIF v_to = 'tbsp' THEN RETURN p_quantity * 2.0;
        ELSIF v_to = 'tsp' THEN RETURN p_quantity * 6.0;
        ELSIF v_to = 'pint' THEN RETURN p_quantity * 0.0625;
        ELSIF v_to = 'quart' THEN RETURN p_quantity * 0.03125;
        ELSIF v_to = 'gallon' THEN RETURN p_quantity * 0.0078125;
        END IF;
    END IF;

    -- pint conversions
    IF v_from = 'pint' THEN
        IF v_to = 'liter' OR v_to = 'l' THEN RETURN p_quantity * 0.473176;
        ELSIF v_to = 'ml' OR v_to = 'milliliter' THEN RETURN p_quantity * 473.176;
        ELSIF v_to = 'cup' THEN RETURN p_quantity * 2.0;
        ELSIF v_to = 'tbsp' THEN RETURN p_quantity * 32.0;
        ELSIF v_to = 'tsp' THEN RETURN p_quantity * 96.0;
        ELSIF v_to = 'floz' THEN RETURN p_quantity * 16.0;
        ELSIF v_to = 'quart' THEN RETURN p_quantity * 0.5;
        ELSIF v_to = 'gallon' THEN RETURN p_quantity * 0.125;
        END IF;
    END IF;

    -- quart conversions
    IF v_from = 'quart' THEN
        IF v_to = 'liter' OR v_to = 'l' THEN RETURN p_quantity * 0.946353;
        ELSIF v_to = 'ml' OR v_to = 'milliliter' THEN RETURN p_quantity * 946.353;
        ELSIF v_to = 'cup' THEN RETURN p_quantity * 4.0;
        ELSIF v_to = 'tbsp' THEN RETURN p_quantity * 64.0;
        ELSIF v_to = 'tsp' THEN RETURN p_quantity * 192.0;
        ELSIF v_to = 'floz' THEN RETURN p_quantity * 32.0;
        ELSIF v_to = 'pint' THEN RETURN p_quantity * 2.0;
        ELSIF v_to = 'gallon' THEN RETURN p_quantity * 0.25;
        END IF;
    END IF;

    -- gallon conversions
    IF v_from = 'gallon' THEN
        IF v_to = 'liter' OR v_to = 'l' THEN RETURN p_quantity * 3.78541;
        ELSIF v_to = 'ml' OR v_to = 'milliliter' THEN RETURN p_quantity * 3785.41;
        ELSIF v_to = 'cup' THEN RETURN p_quantity * 16.0;
        ELSIF v_to = 'tbsp' THEN RETURN p_quantity * 256.0;
        ELSIF v_to = 'tsp' THEN RETURN p_quantity * 768.0;
        ELSIF v_to = 'floz' THEN RETURN p_quantity * 128.0;
        ELSIF v_to = 'pint' THEN RETURN p_quantity * 8.0;
        ELSIF v_to = 'quart' THEN RETURN p_quantity * 4.0;
        END IF;
    END IF;

    -- =========================================================================
    -- COUNT CONVERSIONS (incl. local egg units)
    -- =========================================================================

    -- biji is 1 piece
    IF v_from = 'biji' THEN
        IF v_to IN ('pcs', 'pieces', 'unit', 'units', 'biji') THEN RETURN p_quantity;
        ELSIF v_to = 'dozen' THEN RETURN p_quantity * 0.0833;
        ELSIF v_to IN ('papan', 'sarang', 'tray') THEN RETURN p_quantity / 30.0;
        END IF;
    END IF;

    -- papan/sarang/tray is 30 pieces
    IF v_from IN ('papan', 'sarang', 'tray') THEN
        IF v_to IN ('pcs', 'pieces', 'unit', 'units', 'biji') THEN RETURN p_quantity * 30.0;
        ELSIF v_to = 'dozen' THEN RETURN p_quantity * 2.5;
        ELSIF v_to IN ('papan', 'sarang', 'tray') THEN RETURN p_quantity;
        END IF;
    END IF;

    -- dozen conversions
    IF v_from = 'dozen' THEN
        IF v_to IN ('pcs', 'pieces', 'unit', 'units', 'biji') THEN RETURN p_quantity * 12;
        ELSIF v_to IN ('papan', 'sarang', 'tray') THEN RETURN (p_quantity * 12) / 30.0;
        END IF;
    END IF;

    -- pcs/pieces/unit/units conversions
    IF v_from IN ('pcs', 'pieces', 'unit', 'units') THEN
        IF v_to = 'dozen' THEN RETURN p_quantity * 0.0833;
        ELSIF v_to IN ('pcs', 'pieces', 'unit', 'units') THEN RETURN p_quantity;
        ELSIF v_to = 'biji' THEN RETURN p_quantity;
        ELSIF v_to IN ('papan', 'sarang', 'tray') THEN RETURN p_quantity / 30.0;
        END IF;
    END IF;

    -- If conversion not found, log warning and return original
    RAISE WARNING 'Unit conversion not found: % to %. Returning original quantity. This may cause incorrect calculations!', p_from_unit, p_to_unit;
    RETURN p_quantity;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION convert_unit IS 'Enhanced unit conversion incl. local egg units: biji (1) and papan/sarang/tray (30 biji)';


