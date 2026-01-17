-- =====================================================
-- PRICING TIERS SYSTEM FOR POCKETBIZZ
-- =====================================================
-- Implements 3-tier pricing with automatic tier detection
-- Tier 1: Early Adopter (RM29/bulan) - 100 subscribers pertama
-- Tier 2: Growth (RM39/bulan) - 2,000 subscribers seterusnya  
-- Tier 3: Standard (RM49/bulan) - unlimited selepas tu
-- =====================================================

-- 1. CREATE PRICING TIERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS pricing_tiers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tier_order INTEGER NOT NULL UNIQUE, -- 1, 2, 3 for sorting
    tier_name TEXT NOT NULL UNIQUE,
    tier_name_display TEXT NOT NULL, -- Display name in BM
    price_monthly DECIMAL(10,2) NOT NULL,
    price_yearly DECIMAL(10,2), -- Optional yearly price
    max_subscribers INTEGER, -- NULL means unlimited
    current_subscribers INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    benefits JSONB, -- Additional benefits per tier
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. INSERT DEFAULT PRICING TIERS
-- =====================================================
INSERT INTO pricing_tiers (tier_order, tier_name, tier_name_display, price_monthly, price_yearly, max_subscribers, description, benefits) VALUES
(1, 'early_adopter', 'Early Adopter', 29.00, 290.00, 100, 
    'Harga istimewa untuk 100 subscriber pertama. Harga ini kekal selama-lamanya!',
    '{"grandfather_clause": true, "priority_support": true, "early_access_features": true}'::jsonb
),
(2, 'growth', 'Growth', 39.00, 390.00, 2000, 
    'Harga khas untuk 2,000 subscriber seterusnya. Harga ini kekal untuk subscriber yang mendaftar dalam tier ini.',
    '{"grandfather_clause": true, "priority_support": false, "early_access_features": false}'::jsonb
),
(3, 'standard', 'Standard', 49.00, 490.00, NULL, 
    'Harga standard selepas kuota awal habis.',
    '{"grandfather_clause": true, "priority_support": false, "early_access_features": false}'::jsonb
)
ON CONFLICT (tier_name) DO NOTHING;

-- 3. CREATE INDEX FOR PERFORMANCE
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_pricing_tiers_active ON pricing_tiers(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_pricing_tiers_order ON pricing_tiers(tier_order);

-- 4. FUNCTION: GET CURRENT ACTIVE TIER
-- =====================================================
-- Returns the current tier that new subscribers should be assigned to
CREATE OR REPLACE FUNCTION get_current_pricing_tier()
RETURNS TABLE (
    tier_id UUID,
    tier_name TEXT,
    tier_name_display TEXT,
    price_monthly DECIMAL(10,2),
    price_yearly DECIMAL(10,2),
    max_subscribers INTEGER,
    current_subscribers INTEGER,
    slots_remaining INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.id,
        pt.tier_name,
        pt.tier_name_display,
        pt.price_monthly,
        pt.price_yearly,
        pt.max_subscribers,
        pt.current_subscribers,
        CASE 
            WHEN pt.max_subscribers IS NULL THEN NULL
            ELSE pt.max_subscribers - pt.current_subscribers
        END AS slots_remaining
    FROM pricing_tiers pt
    WHERE pt.is_active = true
    AND (pt.max_subscribers IS NULL OR pt.current_subscribers < pt.max_subscribers)
    ORDER BY pt.tier_order ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. FUNCTION: GET ALL TIERS WITH STATUS
-- =====================================================
-- Returns all tiers with their current status (for UI display)
CREATE OR REPLACE FUNCTION get_all_pricing_tiers()
RETURNS TABLE (
    tier_id UUID,
    tier_order INTEGER,
    tier_name TEXT,
    tier_name_display TEXT,
    price_monthly DECIMAL(10,2),
    price_yearly DECIMAL(10,2),
    max_subscribers INTEGER,
    current_subscribers INTEGER,
    slots_remaining INTEGER,
    is_current_tier BOOLEAN,
    is_sold_out BOOLEAN,
    description TEXT
) AS $$
DECLARE
    current_tier_name TEXT;
BEGIN
    -- Get current active tier name
    SELECT pt.tier_name INTO current_tier_name
    FROM pricing_tiers pt
    WHERE pt.is_active = true
    AND (pt.max_subscribers IS NULL OR pt.current_subscribers < pt.max_subscribers)
    ORDER BY pt.tier_order ASC
    LIMIT 1;

    RETURN QUERY
    SELECT 
        pt.id,
        pt.tier_order,
        pt.tier_name,
        pt.tier_name_display,
        pt.price_monthly,
        pt.price_yearly,
        pt.max_subscribers,
        pt.current_subscribers,
        CASE 
            WHEN pt.max_subscribers IS NULL THEN NULL
            ELSE GREATEST(0, pt.max_subscribers - pt.current_subscribers)
        END AS slots_remaining,
        pt.tier_name = current_tier_name AS is_current_tier,
        CASE 
            WHEN pt.max_subscribers IS NULL THEN false
            ELSE pt.current_subscribers >= pt.max_subscribers
        END AS is_sold_out,
        pt.description
    FROM pricing_tiers pt
    WHERE pt.is_active = true
    ORDER BY pt.tier_order ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. FUNCTION: INCREMENT TIER SUBSCRIBER COUNT
-- =====================================================
-- Called when a new paid subscription is created
CREATE OR REPLACE FUNCTION increment_tier_subscriber_count(p_tier_name TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_updated BOOLEAN := false;
BEGIN
    UPDATE pricing_tiers
    SET 
        current_subscribers = current_subscribers + 1,
        updated_at = NOW()
    WHERE tier_name = p_tier_name
    AND is_active = true;
    
    v_updated := FOUND;
    RETURN v_updated;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. FUNCTION: DECREMENT TIER SUBSCRIBER COUNT (for cancellations/refunds)
-- =====================================================
CREATE OR REPLACE FUNCTION decrement_tier_subscriber_count(p_tier_name TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_updated BOOLEAN := false;
BEGIN
    UPDATE pricing_tiers
    SET 
        current_subscribers = GREATEST(0, current_subscribers - 1),
        updated_at = NOW()
    WHERE tier_name = p_tier_name
    AND is_active = true;
    
    v_updated := FOUND;
    RETURN v_updated;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. ADD TIER REFERENCE TO USER_SUBSCRIPTIONS TABLE
-- =====================================================
-- Add pricing_tier_name column to track which tier each user subscribed at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_subscriptions' 
        AND column_name = 'pricing_tier_name'
    ) THEN
        ALTER TABLE user_subscriptions 
        ADD COLUMN pricing_tier_name TEXT DEFAULT NULL;
    END IF;
    
    -- Add locked_price_monthly to preserve grandfather clause
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_subscriptions' 
        AND column_name = 'locked_price_monthly'
    ) THEN
        ALTER TABLE user_subscriptions 
        ADD COLUMN locked_price_monthly DECIMAL(10,2) DEFAULT NULL;
    END IF;
END $$;

-- 9. FUNCTION: ASSIGN TIER TO NEW SUBSCRIPTION
-- =====================================================
-- Automatically assigns current tier and locks in price (grandfather clause)
CREATE OR REPLACE FUNCTION assign_tier_to_subscription()
RETURNS TRIGGER AS $$
DECLARE
    v_tier RECORD;
BEGIN
    -- Only assign tier for paid subscriptions (not free trial)
    IF NEW.plan_type = 'pro' AND NEW.status = 'active' THEN
        -- Get current active tier
        SELECT * INTO v_tier FROM get_current_pricing_tier();
        
        IF v_tier IS NOT NULL THEN
            NEW.pricing_tier_name := v_tier.tier_name;
            NEW.locked_price_monthly := v_tier.price_monthly;
            
            -- Increment tier count
            PERFORM increment_tier_subscriber_count(v_tier.tier_name);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. CREATE TRIGGER FOR AUTO TIER ASSIGNMENT
-- =====================================================
DROP TRIGGER IF EXISTS trigger_assign_tier_to_subscription ON user_subscriptions;
CREATE TRIGGER trigger_assign_tier_to_subscription
    BEFORE INSERT ON user_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION assign_tier_to_subscription();

-- 11. TRIGGER FOR TIER ASSIGNMENT ON STATUS UPDATE
-- =====================================================
CREATE OR REPLACE FUNCTION handle_subscription_tier_on_update()
RETURNS TRIGGER AS $$
DECLARE
    v_tier RECORD;
BEGIN
    -- When subscription upgrades from trial to pro
    IF OLD.plan_type = 'trial' AND NEW.plan_type = 'pro' AND NEW.status = 'active' THEN
        -- Only assign tier if not already assigned
        IF NEW.pricing_tier_name IS NULL THEN
            SELECT * INTO v_tier FROM get_current_pricing_tier();
            
            IF v_tier IS NOT NULL THEN
                NEW.pricing_tier_name := v_tier.tier_name;
                NEW.locked_price_monthly := v_tier.price_monthly;
                
                -- Increment tier count
                PERFORM increment_tier_subscriber_count(v_tier.tier_name);
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_subscription_tier_on_update ON user_subscriptions;
CREATE TRIGGER trigger_subscription_tier_on_update
    BEFORE UPDATE ON user_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION handle_subscription_tier_on_update();

-- 12. RPC FOR FLUTTER APP TO GET PRICING INFO
-- =====================================================
-- This function is called by the Flutter app to display pricing
CREATE OR REPLACE FUNCTION get_subscription_pricing_info()
RETURNS JSON AS $$
DECLARE
    v_current_tier RECORD;
    v_all_tiers JSON;
    v_result JSON;
BEGIN
    -- Get current tier
    SELECT * INTO v_current_tier FROM get_current_pricing_tier();
    
    -- Get all tiers
    SELECT json_agg(row_to_json(t)) INTO v_all_tiers
    FROM get_all_pricing_tiers() t;
    
    -- Build result
    v_result := json_build_object(
        'current_tier', json_build_object(
            'tier_name', v_current_tier.tier_name,
            'tier_name_display', v_current_tier.tier_name_display,
            'price_monthly', v_current_tier.price_monthly,
            'price_yearly', v_current_tier.price_yearly,
            'slots_remaining', v_current_tier.slots_remaining,
            'max_subscribers', v_current_tier.max_subscribers
        ),
        'all_tiers', v_all_tiers,
        'has_early_adopter_slots', (
            SELECT current_subscribers < max_subscribers 
            FROM pricing_tiers 
            WHERE tier_name = 'early_adopter' AND is_active = true
        )
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. GRANT PERMISSIONS
-- =====================================================
GRANT SELECT ON pricing_tiers TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_pricing_tier() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_pricing_tiers() TO authenticated;
GRANT EXECUTE ON FUNCTION get_subscription_pricing_info() TO authenticated;

-- 14. UPDATE EXISTING EARLY ADOPTERS (BACKFILL)
-- =====================================================
-- Update existing paid subscribers to early_adopter tier
-- This preserves their grandfather clause pricing
UPDATE user_subscriptions
SET 
    pricing_tier_name = 'early_adopter',
    locked_price_monthly = 29.00
WHERE plan_type = 'pro' 
AND status = 'active'
AND pricing_tier_name IS NULL;

-- Update the early_adopter tier count based on existing subscribers
UPDATE pricing_tiers
SET current_subscribers = (
    SELECT COUNT(*) 
    FROM user_subscriptions 
    WHERE pricing_tier_name = 'early_adopter'
    AND status = 'active'
)
WHERE tier_name = 'early_adopter';

-- =====================================================
-- SUMMARY
-- =====================================================
-- ✅ pricing_tiers table with 3 tiers
-- ✅ Functions for tier management
-- ✅ Auto-assignment trigger for new subscriptions
-- ✅ Grandfather clause with locked_price_monthly
-- ✅ RPC function for Flutter app
-- ✅ Backfill existing subscribers to early_adopter tier
-- =====================================================
