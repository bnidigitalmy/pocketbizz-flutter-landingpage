-- ============================================================================
-- FIX DELIVERY INVOICE NUMBER GENERATION
-- Fix race condition by including microseconds for uniqueness
-- ============================================================================

BEGIN;

-- Drop existing function and trigger
DROP TRIGGER IF EXISTS trigger_set_delivery_invoice_number ON vendor_deliveries;
DROP FUNCTION IF EXISTS set_delivery_invoice_number();
DROP FUNCTION IF EXISTS generate_delivery_invoice_number();

-- Create improved invoice number generation function
-- Format: DEL-YYMM-XXXX-UUUUUU (where UUUUUU is microseconds for uniqueness)
-- Uses advisory lock to prevent race conditions
CREATE OR REPLACE FUNCTION generate_delivery_invoice_number()
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT := 'DEL';
    v_year TEXT := TO_CHAR(NOW(), 'YY');
    v_month TEXT := TO_CHAR(NOW(), 'MM');
    v_seq_num INTEGER;
    v_timestamp_suffix TEXT;
    v_invoice_number TEXT;
    v_lock_id INTEGER := 12345; -- Advisory lock ID for invoice generation
BEGIN
    -- Acquire advisory lock to prevent concurrent invoice number generation
    PERFORM pg_advisory_xact_lock(v_lock_id);
    
    -- Get next sequence number for this month
    -- Handle both old format (DEL-YYMM-XXXX) and new format (DEL-YYMM-XXXX-UUUUUU)
    SELECT COALESCE(MAX(
        CASE 
            -- New format: DEL-YYMM-XXXX-UUUUUU
            WHEN invoice_number ~ ('^' || v_prefix || '-' || v_year || v_month || '-[0-9]{4}-[0-9]{6}$') THEN
                CAST(SUBSTRING(invoice_number FROM LENGTH(v_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
            -- Old format: DEL-YYMM-XXXX
            WHEN invoice_number ~ ('^' || v_prefix || '-' || v_year || v_month || '-[0-9]{4}$') THEN
                CAST(SUBSTRING(invoice_number FROM LENGTH(v_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
            ELSE 0
        END
    ), 0) + 1
    INTO v_seq_num
    FROM vendor_deliveries
    WHERE invoice_number LIKE v_prefix || '-' || v_year || v_month || '-%';
    
    -- Get timestamp suffix (last 6 digits of microseconds) for additional uniqueness
    v_timestamp_suffix := LPAD(TO_CHAR(EXTRACT(MICROSECONDS FROM NOW())::BIGINT % 1000000, 'FM999999'), 6, '0');
    
    -- Format: DEL-YYMM-XXXX-UUUUUU
    v_invoice_number := v_prefix || '-' || v_year || v_month || '-' || 
                       LPAD(v_seq_num::TEXT, 4, '0') || '-' || v_timestamp_suffix;
    
    -- Double-check for uniqueness (shouldn't happen with lock, but safety check)
    WHILE EXISTS (SELECT 1 FROM vendor_deliveries WHERE invoice_number = v_invoice_number) LOOP
        -- If somehow duplicate, increment sequence and regenerate
        v_seq_num := v_seq_num + 1;
        v_timestamp_suffix := LPAD(TO_CHAR(EXTRACT(MICROSECONDS FROM NOW())::BIGINT % 1000000, 'FM999999'), 6, '0');
        v_invoice_number := v_prefix || '-' || v_year || v_month || '-' || 
                           LPAD(v_seq_num::TEXT, 4, '0') || '-' || v_timestamp_suffix;
    END LOOP;
    
    RETURN v_invoice_number;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger function
CREATE OR REPLACE FUNCTION set_delivery_invoice_number()
RETURNS TRIGGER AS $$

BEGIN
    IF NEW.invoice_number IS NULL OR NEW.invoice_number = '' THEN
        NEW.invoice_number := generate_delivery_invoice_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
CREATE TRIGGER trigger_set_delivery_invoice_number
    BEFORE INSERT ON vendor_deliveries
    FOR EACH ROW
    EXECUTE FUNCTION set_delivery_invoice_number();

COMMIT;

