-- ============================================================================
-- SUBSCRIPTION SYSTEM FOR POCKETBIZZ
-- Supports: 1 month, 3 months, 6 months, 12 months packages
-- Early Adopter: First 100 users get RM 29/month (lifetime discount)
-- Standard: RM 39/month
-- ============================================================================

-- SUBSCRIPTION PLANS TABLE
-- Defines available subscription packages
CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL, -- e.g., "1 Month", "3 Months", "6 Months", "12 Months"
    duration_months INTEGER NOT NULL CHECK (duration_months > 0),
    price_per_month NUMERIC(10,2) NOT NULL, -- Price per month (RM 39 or RM 29 for early adopters)
    total_price NUMERIC(10,2) NOT NULL, -- Total price for the package
    discount_percentage NUMERIC(5,2) DEFAULT 0, -- Discount % for longer commitments
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(duration_months)
);

-- SUBSCRIPTIONS TABLE
-- Tracks user subscriptions
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id),
    
    -- Pricing
    price_per_month NUMERIC(10,2) NOT NULL, -- Locked price (RM 29 for early adopters, RM 39 standard)
    total_amount NUMERIC(10,2) NOT NULL, -- Total paid for this subscription period
    discount_applied NUMERIC(10,2) DEFAULT 0, -- Discount amount if any
    
    -- Status
    status TEXT NOT NULL CHECK (status IN ('trial', 'active', 'expired', 'cancelled', 'pending_payment')),
    is_early_adopter BOOLEAN NOT NULL DEFAULT FALSE, -- True if user is early adopter (RM 29/month)
    
    -- Dates
    trial_started_at TIMESTAMPTZ, -- When trial started
    trial_ends_at TIMESTAMPTZ, -- When trial ends (7 days from start)
    started_at TIMESTAMPTZ, -- When paid subscription started
    expires_at TIMESTAMPTZ NOT NULL, -- When subscription expires
    cancelled_at TIMESTAMPTZ, -- When user cancelled (if applicable)
    
    -- Payment
    payment_gateway TEXT DEFAULT 'bcl_my', -- Payment gateway used
    payment_reference TEXT, -- Reference from payment gateway
    payment_status TEXT CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
    payment_completed_at TIMESTAMPTZ,
    
    -- Metadata
    auto_renew BOOLEAN NOT NULL DEFAULT TRUE, -- Auto-renew subscription
    notes TEXT, -- Any additional notes
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create unique index for active subscriptions (one active per user)
-- Using partial index to only enforce uniqueness for active/trial statuses
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_subscription 
ON subscriptions (user_id) 
WHERE status IN ('trial', 'active');

-- SUBSCRIPTION PAYMENTS TABLE
-- Tracks payment history
CREATE TABLE IF NOT EXISTS subscription_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Payment details
    amount NUMERIC(10,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'MYR',
    payment_gateway TEXT NOT NULL DEFAULT 'bcl_my',
    payment_reference TEXT, -- Reference from payment gateway
    gateway_transaction_id TEXT, -- Transaction ID from gateway
    
    -- Status
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    failure_reason TEXT, -- If payment failed
    
    -- Metadata
    payment_method TEXT, -- e.g., 'credit_card', 'online_banking', 'e_wallet'
    paid_at TIMESTAMPTZ, -- When payment was completed
    receipt_url TEXT, -- URL to receipt/invoice
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- EARLY ADOPTER TRACKING
-- Tracks first 100 users for early adopter pricing
CREATE TABLE IF NOT EXISTS early_adopters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    user_email TEXT NOT NULL,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    subscription_started_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at ON subscriptions(expires_at);
CREATE INDEX IF NOT EXISTS idx_subscriptions_trial_ends_at ON subscriptions(trial_ends_at);

CREATE INDEX IF NOT EXISTS idx_subscription_payments_subscription_id ON subscription_payments(subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_user_id ON subscription_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_status ON subscription_payments(status);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_gateway_transaction_id ON subscription_payments(gateway_transaction_id);

CREATE INDEX IF NOT EXISTS idx_early_adopters_user_id ON early_adopters(user_id);
CREATE INDEX IF NOT EXISTS idx_early_adopters_registered_at ON early_adopters(registered_at);

-- ROW LEVEL SECURITY (RLS)
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE early_adopters ENABLE ROW LEVEL SECURITY;

-- RLS POLICIES: Subscription Plans (Public read)
DROP POLICY IF EXISTS "Anyone can view active subscription plans" ON subscription_plans;
CREATE POLICY "Anyone can view active subscription plans"
    ON subscription_plans FOR SELECT
    USING (is_active = TRUE);

-- RLS POLICIES: Subscriptions (Users can only see their own)
DROP POLICY IF EXISTS "Users can view their own subscriptions" ON subscriptions;
CREATE POLICY "Users can view their own subscriptions"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own subscriptions" ON subscriptions;
CREATE POLICY "Users can insert their own subscriptions"
    ON subscriptions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own subscriptions" ON subscriptions;
CREATE POLICY "Users can update their own subscriptions"
    ON subscriptions FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- RLS POLICIES: Subscription Payments (Users can only see their own)
DROP POLICY IF EXISTS "Users can view their own payments" ON subscription_payments;
CREATE POLICY "Users can view their own payments"
    ON subscription_payments FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own payments" ON subscription_payments;
CREATE POLICY "Users can insert their own payments"
    ON subscription_payments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- RLS POLICIES: Early Adopters (Users can only see their own status)
DROP POLICY IF EXISTS "Users can view their own early adopter status" ON early_adopters;
CREATE POLICY "Users can view their own early adopter status"
    ON early_adopters FOR SELECT
    USING (auth.uid() = user_id);

-- FUNCTIONS: Check if user is early adopter
CREATE OR REPLACE FUNCTION is_early_adopter(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM early_adopters
        WHERE user_id = user_uuid
        AND is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTIONS: Get early adopter count
CREATE OR REPLACE FUNCTION get_early_adopter_count()
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM early_adopters WHERE is_active = TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTIONS: Register early adopter (if under 100)
CREATE OR REPLACE FUNCTION register_early_adopter(user_uuid UUID, user_email TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    current_count INTEGER;
BEGIN
    -- Check current count
    SELECT get_early_adopter_count() INTO current_count;
    
    -- Only allow if under 100
    IF current_count >= 100 THEN
        RETURN FALSE;
    END IF;
    
    -- Check if already registered
    IF EXISTS (SELECT 1 FROM early_adopters WHERE user_id = user_uuid) THEN
        RETURN TRUE; -- Already registered
    END IF;
    
    -- Register as early adopter
    INSERT INTO early_adopters (user_id, user_email)
    VALUES (user_uuid, user_email)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTIONS: Get user's current subscription status
CREATE OR REPLACE FUNCTION get_user_subscription_status(user_uuid UUID)
RETURNS TABLE (
    subscription_id UUID,
    status TEXT,
    is_trial BOOLEAN,
    trial_ends_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    is_early_adopter BOOLEAN,
    price_per_month NUMERIC,
    plan_name TEXT,
    days_remaining INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.status,
        (s.status = 'trial') as is_trial,
        s.trial_ends_at,
        s.expires_at,
        s.is_early_adopter,
        s.price_per_month,
        sp.name as plan_name,
        CASE 
            WHEN s.status = 'trial' THEN 
                EXTRACT(DAY FROM (s.trial_ends_at - NOW()))::INTEGER
            WHEN s.status = 'active' THEN
                EXTRACT(DAY FROM (s.expires_at - NOW()))::INTEGER
            ELSE 0
        END as days_remaining
    FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.user_id = user_uuid
    AND s.status IN ('trial', 'active')
    ORDER BY s.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TRIGGERS: Update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_subscription_plans_updated_at ON subscription_plans;
CREATE TRIGGER update_subscription_plans_updated_at
    BEFORE UPDATE ON subscription_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscription_payments_updated_at ON subscription_payments;
CREATE TRIGGER update_subscription_payments_updated_at
    BEFORE UPDATE ON subscription_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- INITIAL DATA: Insert subscription plans
-- Standard pricing: RM 39/month
-- Discounts: 6 months (8% off), 12 months (15% off)
-- Early adopter pricing: RM 29/month (handled in application logic)
INSERT INTO subscription_plans (name, duration_months, price_per_month, total_price, discount_percentage, display_order)
VALUES
    ('1 Bulan', 1, 39.00, 39.00, 0.00, 1),
    ('3 Bulan', 3, 39.00, 117.00, 0.00, 2),
    ('6 Bulan', 6, 39.00, 215.28, 8.00, 3),  -- 8% discount: (39 x 6) - 8% = 234 - 18.72 = 215.28
    ('12 Bulan', 12, 39.00, 397.80, 15.00, 4)  -- 15% discount: (39 x 12) - 15% = 468 - 70.20 = 397.80
ON CONFLICT (duration_months) DO UPDATE
SET 
    price_per_month = EXCLUDED.price_per_month,
    total_price = EXCLUDED.total_price,
    discount_percentage = EXCLUDED.discount_percentage,
    updated_at = NOW();

-- Note: Early adopter pricing (RM 29/month) will be calculated in application with same discounts:
-- - 1 Bulan: RM 29 (no discount)
-- - 3 Bulan: RM 87 (RM 29 x 3, no discount)
-- - 6 Bulan: RM 160.08 (RM 29 x 6 - 8% = 174 - 13.92 = 160.08)
-- - 12 Bulan: RM 295.80 (RM 29 x 12 - 15% = 348 - 52.20 = 295.80)

