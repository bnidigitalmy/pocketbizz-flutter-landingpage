-- BOOKING PAYMENTS TABLE
-- Tracks payment history for bookings (deposit + balance payments)
-- Allows multiple payments per booking

BEGIN;

CREATE TABLE IF NOT EXISTS booking_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    booking_id UUID NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
    payment_number TEXT UNIQUE NOT NULL,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_time TIME NOT NULL DEFAULT CURRENT_TIME,
    payment_amount NUMERIC(12,2) NOT NULL CHECK (payment_amount > 0),
    payment_method TEXT NOT NULL CHECK (payment_method IN (
        'cash', 'bank_transfer', 'cheque', 'credit_card', 'e_wallet', 'other'
    )),
    payment_reference TEXT, -- Bank reference, cheque number, etc.
    notes TEXT,
    receipt_generated BOOLEAN DEFAULT false,
    receipt_url TEXT, -- URL to receipt PDF if generated
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_booking_payments_booking ON booking_payments (booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_payments_owner ON booking_payments (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_booking_payments_date ON booking_payments (payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_booking_payments_number ON booking_payments (payment_number);

-- Enable RLS
ALTER TABLE booking_payments ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY booking_payments_select_own ON booking_payments
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY booking_payments_insert_own ON booking_payments
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY booking_payments_update_own ON booking_payments
    FOR UPDATE
    USING (business_owner_id = auth.uid())
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY booking_payments_delete_own ON booking_payments
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- Function to generate payment number (PAY-BOOKING-YYMM-0001)
CREATE OR REPLACE FUNCTION generate_booking_payment_number()
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT := 'PAY';
    v_year TEXT := TO_CHAR(CURRENT_DATE, 'YY');
    v_month TEXT := TO_CHAR(CURRENT_DATE, 'MM');
    v_seq_num INTEGER;
    v_payment_number TEXT;
BEGIN
    -- Get next sequence number for this month
    SELECT COALESCE(MAX(CAST(SUBSTRING(payment_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM booking_payments
    WHERE payment_number LIKE v_prefix || '-' || v_year || v_month || '%';

    -- Format: PAY-YYMM-0001
    v_payment_number := v_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');

    RETURN v_payment_number;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate payment number
CREATE OR REPLACE FUNCTION set_booking_payment_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_number IS NULL OR NEW.payment_number = '' THEN
        NEW.payment_number := generate_booking_payment_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_booking_payment_number
    BEFORE INSERT ON booking_payments
    FOR EACH ROW
    EXECUTE FUNCTION set_booking_payment_number();

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_booking_payments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_booking_payments_updated_at
    BEFORE UPDATE ON booking_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_booking_payments_updated_at();

-- Add total_paid column to bookings table (calculated from booking_payments)
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS total_paid NUMERIC(12,2) DEFAULT 0;

-- Function to update total_paid in bookings table
CREATE OR REPLACE FUNCTION update_booking_total_paid()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE bookings
    SET total_paid = (
        SELECT COALESCE(SUM(payment_amount), 0)
        FROM booking_payments
        WHERE booking_id = COALESCE(NEW.booking_id, OLD.booking_id)
    )
    WHERE id = COALESCE(NEW.booking_id, OLD.booking_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update total_paid when payment is added/updated/deleted
CREATE TRIGGER trigger_update_booking_total_paid
    AFTER INSERT OR UPDATE OR DELETE ON booking_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_booking_total_paid();

COMMENT ON TABLE booking_payments IS 'Tracks payment history for bookings. Supports multiple payments per booking.';
COMMENT ON COLUMN booking_payments.payment_number IS 'Auto-generated payment number (format: PAY-YYMM-0001)';
COMMENT ON COLUMN booking_payments.payment_amount IS 'Amount paid in this payment';
COMMENT ON COLUMN bookings.total_paid IS 'Total amount paid for the booking (sum of all payments from booking_payments table)';

COMMIT;

