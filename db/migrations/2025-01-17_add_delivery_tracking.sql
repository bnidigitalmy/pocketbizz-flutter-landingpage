-- ============================================================================
-- DELIVERY TRACKING SYSTEM
-- Add timeline/history tracking and notes log for deliveries
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: CREATE DELIVERY_TIMELINE TABLE
-- Track all status changes and important events
-- ============================================================================
CREATE TABLE IF NOT EXISTS delivery_timeline (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delivery_id UUID NOT NULL REFERENCES vendor_deliveries(id) ON DELETE CASCADE,
    business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Event Information
    event_type TEXT NOT NULL CHECK (event_type IN (
        'created',           -- Delivery created
        'status_changed',    -- Status updated (delivered, pending, claimed, rejected)
        'payment_status_changed', -- Payment status updated
        'rejection_added',   -- Rejection recorded
        'rejection_updated', -- Rejection updated
        'invoice_generated', -- Invoice generated
        'note_added',        -- Note added
        'item_added',        -- Item added to delivery
        'item_updated',      -- Item updated
        'item_removed'       -- Item removed
    )),
    
    -- Event Details
    old_value TEXT,          -- Previous value (for status changes)
    new_value TEXT,          -- New value (for status changes)
    description TEXT,        -- Human-readable description
    metadata JSONB,          -- Additional data (e.g., item details, user info)
    
    -- User who made the change
    changed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    changed_by_name TEXT,    -- Denormalized for performance
    
    -- Timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_delivery_timeline_delivery ON delivery_timeline(delivery_id);
CREATE INDEX idx_delivery_timeline_owner ON delivery_timeline(business_owner_id);
CREATE INDEX idx_delivery_timeline_event_type ON delivery_timeline(event_type);
CREATE INDEX idx_delivery_timeline_created_at ON delivery_timeline(created_at DESC);

-- Enable RLS
ALTER TABLE delivery_timeline ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY delivery_timeline_select_policy ON delivery_timeline
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY delivery_timeline_insert_policy ON delivery_timeline
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 2: CREATE DELIVERY_NOTES_LOG TABLE
-- Track multiple notes/updates for a delivery
-- ============================================================================
CREATE TABLE IF NOT EXISTS delivery_notes_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delivery_id UUID NOT NULL REFERENCES vendor_deliveries(id) ON DELETE CASCADE,
    business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Note Content
    note TEXT NOT NULL,
    note_type TEXT DEFAULT 'general' CHECK (note_type IN (
        'general',      -- General note
        'internal',     -- Internal note (not visible to vendor)
        'vendor_note',  -- Note from/to vendor
        'issue',        -- Issue/problem reported
        'resolution'    -- Resolution/update
    )),
    
    -- User who added the note
    added_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    added_by_name TEXT, -- Denormalized for performance
    
    -- Timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_delivery_notes_log_delivery ON delivery_notes_log(delivery_id);
CREATE INDEX idx_delivery_notes_log_owner ON delivery_notes_log(business_owner_id);
CREATE INDEX idx_delivery_notes_log_created_at ON delivery_notes_log(created_at DESC);

-- Enable RLS
ALTER TABLE delivery_notes_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY delivery_notes_log_select_policy ON delivery_notes_log
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY delivery_notes_log_insert_policy ON delivery_notes_log
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY delivery_notes_log_update_policy ON delivery_notes_log
    FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY delivery_notes_log_delete_policy ON delivery_notes_log
    FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 3: CREATE FUNCTION TO AUTO-LOG STATUS CHANGES
-- ============================================================================
CREATE OR REPLACE FUNCTION log_delivery_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_user_name TEXT;
BEGIN
    -- Get current user info
    v_user_id := auth.uid();
    
    -- Get user name (if available)
    SELECT full_name INTO v_user_name
    FROM users
    WHERE id = v_user_id;
    
    -- Log status change if status changed
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO delivery_timeline (
            delivery_id,
            business_owner_id,
            event_type,
            old_value,
            new_value,
            description,
            changed_by_user_id,
            changed_by_name
        ) VALUES (
            NEW.id,
            NEW.business_owner_id,
            'status_changed',
            OLD.status,
            NEW.status,
            format('Status changed from %s to %s', OLD.status, NEW.status),
            v_user_id,
            COALESCE(v_user_name, 'System')
        );
    END IF;
    
    -- Log payment status change if changed
    IF OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
        INSERT INTO delivery_timeline (
            delivery_id,
            business_owner_id,
            event_type,
            old_value,
            new_value,
            description,
            changed_by_user_id,
            changed_by_name
        ) VALUES (
            NEW.id,
            NEW.business_owner_id,
            'payment_status_changed',
            COALESCE(OLD.payment_status, 'null'),
            COALESCE(NEW.payment_status, 'null'),
            format('Payment status changed from %s to %s', 
                COALESCE(OLD.payment_status, 'null'), 
                COALESCE(NEW.payment_status, 'null')),
            v_user_id,
            COALESCE(v_user_name, 'System')
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_log_delivery_status_change ON vendor_deliveries;
CREATE TRIGGER trigger_log_delivery_status_change
    AFTER UPDATE ON vendor_deliveries
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.payment_status IS DISTINCT FROM NEW.payment_status)
    EXECUTE FUNCTION log_delivery_status_change();

-- ============================================================================
-- STEP 4: CREATE FUNCTION TO LOG DELIVERY CREATION
-- ============================================================================
CREATE OR REPLACE FUNCTION log_delivery_creation()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_user_name TEXT;
BEGIN
    -- Get current user info
    v_user_id := auth.uid();
    
    -- Get user name (if available)
    SELECT full_name INTO v_user_name
    FROM users
    WHERE id = v_user_id;
    
    -- Log delivery creation
    INSERT INTO delivery_timeline (
        delivery_id,
        business_owner_id,
        event_type,
        new_value,
        description,
        changed_by_user_id,
        changed_by_name,
        metadata
    ) VALUES (
        NEW.id,
        NEW.business_owner_id,
        'created',
        NEW.status,
        format('Delivery created for %s', NEW.vendor_name),
        v_user_id,
        COALESCE(v_user_name, 'System'),
        jsonb_build_object(
            'vendor_id', NEW.vendor_id,
            'vendor_name', NEW.vendor_name,
            'invoice_number', NEW.invoice_number,
            'total_amount', NEW.total_amount
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_log_delivery_creation ON vendor_deliveries;
CREATE TRIGGER trigger_log_delivery_creation
    AFTER INSERT ON vendor_deliveries
    FOR EACH ROW
    EXECUTE FUNCTION log_delivery_creation();

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ DELIVERY TRACKING SYSTEM ADDED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ delivery_timeline table created';
    RAISE NOTICE '✅ delivery_notes_log table created';
    RAISE NOTICE '✅ Auto-logging triggers created';
    RAISE NOTICE '';
    RAISE NOTICE 'Features:';
    RAISE NOTICE '  - Track all status changes';
    RAISE NOTICE '  - Track payment status changes';
    RAISE NOTICE '  - Multiple notes per delivery';
    RAISE NOTICE '  - Timeline history with timestamps';
    RAISE NOTICE '';
END $$;

