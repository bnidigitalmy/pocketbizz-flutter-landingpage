-- ============================================================================
-- PRICING TIERS SYSTEM FOR POCKETBIZZ
-- 3-Tier Pricing with Grandfather Clause & Lifetime Lock
-- ============================================================================
-- Tier 1: Early Adopter - RM29/month (First 100 users)
-- Tier 2: Growth - RM39/month (Users 101-2000)
-- Tier 3: Standard - RM49/month (Users 2001+)
-- ============================================================================

-- ============================================================================
-- TABLE: pricing_tiers
-- Tracks pricing tiers and their quotas
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.pricing_tiers (
    id SERIAL PRIMARY KEY,
    tier_key TEXT NOT NULL UNIQUE,           -- 'early_adopter', 'growth', 'standard'
    tier_name TEXT NOT NULL,                  -- Display name: 'Early Adopter', 'Growth', 'Standard'
    tier_name_ms TEXT NOT NULL,               -- Malay name: 'Peneroka Awal', 'Pertumbuhan', 'Standard'
    price_per_month NUMERIC(10,2) NOT NULL,   -- 29.00, 39.00, 49.00
    price_per_month_display TEXT NOT NULL,    -- 'RM 29', 'RM 39', 'RM 49'
    max_subscribers INT,                       -- 100, 2000, NULL (unlimited for standard)
    current_count INT NOT NULL DEFAULT 0,     -- Real-time count of subscribers in this tier
    savings_vs_standard NUMERIC(10,2),        -- Savings per year vs standard (RM49)
    tier_order INT NOT NULL DEFAULT 0,        -- Display order (1, 2, 3)
    badge_color TEXT DEFAULT '#4CAF50',       -- Color for UI badge
    badge_emoji TEXT DEFAULT '🏷️',            -- Emoji for tier
    description TEXT,                          -- Short description
    description_ms TEXT,                       -- Malay description
    is_active BOOLEAN NOT NULL DEFAULT TRUE,  -- Is tier currently available
    is_lifetime_locked BOOLEAN NOT NULL DEFAULT TRUE, -- Price locked forever for subscribers
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INSERT DEFAULT PRICING TIERS
-- ============================================================================
INSERT INTO public.pricing_tiers (
    tier_key, tier_name, tier_name_ms, price_per_month, price_per_month_display,
    max_subscribers, savings_vs_standard, tier_order, badge_color, badge_emoji,
    description, description_ms, is_lifetime_locked
) VALUES 
(
    'early_adopter',
    'Early Adopter',
    'Peneroka Awal',
    29.00,
    'RM 29',
    100,
    240.00,  -- (49-29) * 12 = RM240/year savings
    1,
    '#FFD700',  -- Gold
    '🥇',
    'Exclusive price for first 100 subscribers. Lifetime locked!',
    'Harga eksklusif untuk 100 pelanggan pertama. Harga kekal selamanya!',
    TRUE
),
(
    'growth',
    'Growth',
    'Pertumbuhan',
    39.00,
    'RM 39',
    2000,
    120.00,  -- (49-39) * 12 = RM120/year savings
    2,
    '#C0C0C0',  -- Silver
    '🥈',
    'Special price for early supporters. Lifetime locked!',
    'Harga istimewa untuk penyokong awal. Harga kekal selamanya!',
    TRUE
),
(
    'standard',
    'Standard',
    'Standard',
    49.00,
    'RM 49',
    NULL,  -- Unlimited
    0.00,
    3,
    '#CD7F32',  -- Bronze
    '🥉',
    'Full-featured access at standard price.',
    'Akses penuh pada harga standard.',
    TRUE
)
ON CONFLICT (tier_key) DO UPDATE SET
    tier_name = EXCLUDED.tier_name,
    tier_name_ms = EXCLUDED.tier_name_ms,
    price_per_month = EXCLUDED.price_per_month,
    price_per_month_display = EXCLUDED.price_per_month_display,
    max_subscribers = EXCLUDED.max_subscribers,
    savings_vs_standard = EXCLUDED.savings_vs_standard,
    tier_order = EXCLUDED.tier_order,
    badge_color = EXCLUDED.badge_color,
    badge_emoji = EXCLUDED.badge_emoji,
    description = EXCLUDED.description,
    description_ms = EXCLUDED.description_ms,
    updated_at = NOW();

-- ============================================================================
-- TABLE: subscriber_tier_history
-- Track which tier each subscriber joined at (for grandfather clause)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.subscriber_tier_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tier_key TEXT NOT NULL REFERENCES public.pricing_tiers(tier_key),
    price_locked_at NUMERIC(10,2) NOT NULL,   -- The price user locked in
    subscribed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,  -- Still an active subscriber?
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_tier UNIQUE (user_id)
);

-- ============================================================================
-- FUNCTION: get_current_pricing_tier()
-- Returns the current available tier for new subscribers
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_current_pricing_tier()
RETURNS TABLE (
    tier_key TEXT,
    tier_name TEXT,
    tier_name_ms TEXT,
    price_per_month NUMERIC,
    price_per_month_display TEXT,
    max_subscribers INT,
    current_count INT,
    remaining_slots INT,
    savings_vs_standard NUMERIC,
    badge_color TEXT,
    badge_emoji TEXT,
    description_ms TEXT,
    is_lifetime_locked BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.tier_key,
        pt.tier_name,
        pt.tier_name_ms,
        pt.price_per_month,
        pt.price_per_month_display,
        pt.max_subscribers,
        pt.current_count,
        CASE 
            WHEN pt.max_subscribers IS NULL THEN NULL::INT
            ELSE (pt.max_subscribers - pt.current_count)
        END as remaining_slots,
        pt.savings_vs_standard,
        pt.badge_color,
        pt.badge_emoji,
        pt.description_ms,
        pt.is_lifetime_locked
    FROM public.pricing_tiers pt
    WHERE pt.is_active = TRUE
    AND (pt.max_subscribers IS NULL OR pt.current_count < pt.max_subscribers)
    ORDER BY pt.tier_order ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: get_all_pricing_tiers()
-- Returns all tiers with their current status (for display)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_all_pricing_tiers()
RETURNS TABLE (
    tier_key TEXT,
    tier_name TEXT,
    tier_name_ms TEXT,
    price_per_month NUMERIC,
    price_per_month_display TEXT,
    max_subscribers INT,
    current_count INT,
    remaining_slots INT,
    percentage_filled NUMERIC,
    savings_vs_standard NUMERIC,
    badge_color TEXT,
    badge_emoji TEXT,
    description_ms TEXT,
    is_available BOOLEAN,
    is_lifetime_locked BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.tier_key,
        pt.tier_name,
        pt.tier_name_ms,
        pt.price_per_month,
        pt.price_per_month_display,
        pt.max_subscribers,
        pt.current_count,
        CASE 
            WHEN pt.max_subscribers IS NULL THEN NULL::INT
            ELSE (pt.max_subscribers - pt.current_count)
        END as remaining_slots,
        CASE 
            WHEN pt.max_subscribers IS NULL THEN 0::NUMERIC
            ELSE ROUND((pt.current_count::NUMERIC / pt.max_subscribers::NUMERIC) * 100, 1)
        END as percentage_filled,
        pt.savings_vs_standard,
        pt.badge_color,
        pt.badge_emoji,
        pt.description_ms,
        (pt.is_active = TRUE AND (pt.max_subscribers IS NULL OR pt.current_count < pt.max_subscribers)) as is_available,
        pt.is_lifetime_locked
    FROM public.pricing_tiers pt
    WHERE pt.is_active = TRUE
    ORDER BY pt.tier_order ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: get_user_locked_tier(user_uuid UUID)
-- Returns the tier a user is locked into (grandfather clause)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_user_locked_tier(user_uuid UUID)
RETURNS TABLE (
    tier_key TEXT,
    tier_name TEXT,
    tier_name_ms TEXT,
    price_locked_at NUMERIC,
    subscribed_at TIMESTAMPTZ,
    badge_emoji TEXT,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sth.tier_key,
        pt.tier_name,
        pt.tier_name_ms,
        sth.price_locked_at,
        sth.subscribed_at,
        pt.badge_emoji,
        sth.is_active
    FROM public.subscriber_tier_history sth
    JOIN public.pricing_tiers pt ON sth.tier_key = pt.tier_key
    WHERE sth.user_id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: register_subscriber_tier(user_uuid UUID)
-- Registers a new subscriber to the current available tier
-- Returns the tier they were assigned to
-- ============================================================================
CREATE OR REPLACE FUNCTION public.register_subscriber_tier(user_uuid UUID)
RETURNS TABLE (
    success BOOLEAN,
    tier_key TEXT,
    tier_name_ms TEXT,
    price_locked_at NUMERIC,
    message TEXT
) AS $$
DECLARE
    current_tier RECORD;
    existing_tier RECORD;
BEGIN
    -- Check if user already has a tier locked
    SELECT * INTO existing_tier 
    FROM public.subscriber_tier_history 
    WHERE user_id = user_uuid;
    
    IF FOUND THEN
        -- User already has a tier, return their existing tier
        RETURN QUERY
        SELECT 
            TRUE as success,
            existing_tier.tier_key,
            pt.tier_name_ms,
            existing_tier.price_locked_at,
            'Anda sudah mempunyai harga terkunci: ' || pt.price_per_month_display || '/bulan'
        FROM public.pricing_tiers pt
        WHERE pt.tier_key = existing_tier.tier_key;
        RETURN;
    END IF;
    
    -- Get current available tier
    SELECT * INTO current_tier FROM public.get_current_pricing_tier();
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::TEXT, NULL::TEXT, NULL::NUMERIC, 
            'Tiada tier tersedia'::TEXT;
        RETURN;
    END IF;
    
    -- Register user to this tier
    INSERT INTO public.subscriber_tier_history (user_id, tier_key, price_locked_at)
    VALUES (user_uuid, current_tier.tier_key, current_tier.price_per_month);
    
    -- Increment tier count
    UPDATE public.pricing_tiers 
    SET current_count = current_count + 1, updated_at = NOW()
    WHERE pricing_tiers.tier_key = current_tier.tier_key;
    
    RETURN QUERY
    SELECT 
        TRUE as success,
        current_tier.tier_key,
        current_tier.tier_name_ms,
        current_tier.price_per_month,
        'Tahniah! Anda mendapat harga ' || current_tier.price_per_month_display || '/bulan (Tier: ' || current_tier.tier_name_ms || ')'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: get_tier_quota_display()
-- Returns formatted quota display for UI
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_tier_quota_display()
RETURNS TABLE (
    current_tier_key TEXT,
    current_tier_name_ms TEXT,
    current_price_display TEXT,
    slots_remaining INT,
    slots_total INT,
    percentage_filled NUMERIC,
    urgency_message TEXT,
    next_tier_price TEXT
) AS $$
DECLARE
    current_tier RECORD;
    next_tier RECORD;
BEGIN
    -- Get current available tier
    SELECT * INTO current_tier FROM public.get_current_pricing_tier();
    
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    -- Get next tier for comparison
    SELECT * INTO next_tier 
    FROM public.pricing_tiers 
    WHERE tier_order = (
        SELECT tier_order + 1 FROM public.pricing_tiers WHERE tier_key = current_tier.tier_key
    );
    
    RETURN QUERY
    SELECT 
        current_tier.tier_key,
        current_tier.tier_name_ms,
        current_tier.price_per_month_display,
        current_tier.remaining_slots,
        current_tier.max_subscribers,
        CASE 
            WHEN current_tier.max_subscribers IS NULL THEN 0::NUMERIC
            ELSE ROUND((current_tier.current_count::NUMERIC / current_tier.max_subscribers::NUMERIC) * 100, 1)
        END,
        CASE
            WHEN current_tier.remaining_slots IS NULL THEN 'Unlimited slots available'
            WHEN current_tier.remaining_slots <= 10 THEN '🔥 Tinggal ' || current_tier.remaining_slots || ' slot sahaja!'
            WHEN current_tier.remaining_slots <= 20 THEN '⚡ Tinggal ' || current_tier.remaining_slots || ' slot!'
            ELSE '✨ ' || current_tier.remaining_slots || ' slot tersedia'
        END,
        COALESCE(next_tier.price_per_month_display, 'N/A');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: sync_tier_counts_from_early_adopters()
-- Sync existing early_adopters count to new pricing_tiers table
-- Run this once after migration to preserve existing data
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sync_tier_counts_from_early_adopters()
RETURNS TEXT AS $$
DECLARE
    early_adopter_count INT;
BEGIN
    -- Get count from existing early_adopters table
    SELECT COUNT(*) INTO early_adopter_count 
    FROM public.early_adopters 
    WHERE is_active = TRUE;
    
    -- Update pricing_tiers with this count
    UPDATE public.pricing_tiers 
    SET current_count = early_adopter_count, updated_at = NOW()
    WHERE tier_key = 'early_adopter';
    
    -- Also migrate existing early adopters to subscriber_tier_history
    INSERT INTO public.subscriber_tier_history (user_id, tier_key, price_locked_at, subscribed_at)
    SELECT 
        ea.user_id, 
        'early_adopter', 
        29.00,
        COALESCE(ea.subscription_started_at, ea.registered_at)
    FROM public.early_adopters ea
    WHERE ea.is_active = TRUE
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN 'Synced ' || early_adopter_count || ' early adopters to pricing_tiers';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RUN SYNC (Uncomment and run once after migration)
-- ============================================================================
-- SELECT sync_tier_counts_from_early_adopters();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE public.pricing_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriber_tier_history ENABLE ROW LEVEL SECURITY;

-- Pricing tiers - everyone can read
CREATE POLICY "Anyone can view pricing tiers"
    ON public.pricing_tiers FOR SELECT
    USING (true);

-- Subscriber tier history - users can only see their own
CREATE POLICY "Users can view own tier history"
    ON public.subscriber_tier_history FOR SELECT
    USING (auth.uid() = user_id);

-- Allow service role full access
CREATE POLICY "Service role has full access to pricing_tiers"
    ON public.pricing_tiers FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role has full access to subscriber_tier_history"
    ON public.subscriber_tier_history FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_pricing_tiers_tier_key ON public.pricing_tiers(tier_key);
CREATE INDEX IF NOT EXISTS idx_pricing_tiers_is_active ON public.pricing_tiers(is_active);
CREATE INDEX IF NOT EXISTS idx_subscriber_tier_history_user_id ON public.subscriber_tier_history(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriber_tier_history_tier_key ON public.subscriber_tier_history(tier_key);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE OR REPLACE FUNCTION update_pricing_tiers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_pricing_tiers_updated_at ON public.pricing_tiers;
CREATE TRIGGER trigger_pricing_tiers_updated_at
    BEFORE UPDATE ON public.pricing_tiers
    FOR EACH ROW EXECUTE FUNCTION update_pricing_tiers_updated_at();

DROP TRIGGER IF EXISTS trigger_subscriber_tier_history_updated_at ON public.subscriber_tier_history;
CREATE TRIGGER trigger_subscriber_tier_history_updated_at
    BEFORE UPDATE ON public.subscriber_tier_history
    FOR EACH ROW EXECUTE FUNCTION update_pricing_tiers_updated_at();

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================
GRANT SELECT ON public.pricing_tiers TO authenticated;
GRANT SELECT ON public.subscriber_tier_history TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_pricing_tier() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_pricing_tiers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_locked_tier(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tier_quota_display() TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_subscriber_tier(UUID) TO authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE public.pricing_tiers IS 'Stores pricing tier definitions with quota tracking';
COMMENT ON TABLE public.subscriber_tier_history IS 'Tracks which tier each user subscribed at (grandfather clause)';
COMMENT ON FUNCTION public.get_current_pricing_tier() IS 'Returns the current available tier for new subscribers';
COMMENT ON FUNCTION public.get_all_pricing_tiers() IS 'Returns all tiers with status for display';
COMMENT ON FUNCTION public.get_user_locked_tier(UUID) IS 'Returns the locked tier for a specific user';
COMMENT ON FUNCTION public.register_subscriber_tier(UUID) IS 'Registers new subscriber to current available tier';
COMMENT ON FUNCTION public.get_tier_quota_display() IS 'Returns formatted quota info for UI display';
