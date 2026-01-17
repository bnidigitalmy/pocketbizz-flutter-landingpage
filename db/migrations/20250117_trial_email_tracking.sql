-- ============================================================================
-- TRIAL EMAIL TRACKING
-- Track follow-up emails sent to trial users
-- ============================================================================
-- 
-- Purpose:
-- - Track which follow-up emails have been sent to each trial user
-- - Prevent duplicate emails
-- - Enable analytics on email campaign effectiveness
--
-- Email Schedule (7-day trial):
-- Day 0: Welcome Email (existing)
-- Day 1: Feature #1 - Stok & Inventori
-- Day 2: Feature #2 - Pengeluaran & Resepi
-- Day 3: Feature #3 - Jualan & Laporan
-- Day 4: Feature #4 - Tempahan (Booking)
-- Day 5: Feature #5 - Penghantaran ke Vendor
-- Day 6: Feature #6 - Scan Perbelanjaan + Trial Reminder
-- ============================================================================

BEGIN;

-- Create trial email tracking table
CREATE TABLE IF NOT EXISTS trial_email_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    
    -- Email tracking flags
    welcome_email_sent BOOLEAN DEFAULT FALSE,
    welcome_email_sent_at TIMESTAMPTZ,
    
    day1_email_sent BOOLEAN DEFAULT FALSE,  -- Stok & Inventori
    day1_email_sent_at TIMESTAMPTZ,
    
    day2_email_sent BOOLEAN DEFAULT FALSE,  -- Pengeluaran & Resepi
    day2_email_sent_at TIMESTAMPTZ,
    
    day3_email_sent BOOLEAN DEFAULT FALSE,  -- Jualan & Laporan
    day3_email_sent_at TIMESTAMPTZ,
    
    day4_email_sent BOOLEAN DEFAULT FALSE,  -- Tempahan (Booking)
    day4_email_sent_at TIMESTAMPTZ,
    
    day5_email_sent BOOLEAN DEFAULT FALSE,  -- Penghantaran ke Vendor
    day5_email_sent_at TIMESTAMPTZ,
    
    day6_email_sent BOOLEAN DEFAULT FALSE,  -- Scan + Trial Reminder
    day6_email_sent_at TIMESTAMPTZ,
    
    -- Trial info (cached for quick access)
    trial_started_at TIMESTAMPTZ NOT NULL,
    trial_ends_at TIMESTAMPTZ NOT NULL,
    user_email TEXT NOT NULL,
    user_name TEXT,
    
    -- User engagement tracking (optional - for analytics)
    has_added_stock BOOLEAN DEFAULT FALSE,
    has_created_product BOOLEAN DEFAULT FALSE,
    has_recorded_production BOOLEAN DEFAULT FALSE,
    has_recorded_sale BOOLEAN DEFAULT FALSE,
    has_created_booking BOOLEAN DEFAULT FALSE,
    has_recorded_delivery BOOLEAN DEFAULT FALSE,
    has_used_ocr BOOLEAN DEFAULT FALSE,
    
    -- Conversion tracking
    converted_to_paid BOOLEAN DEFAULT FALSE,
    converted_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one tracking record per user
    CONSTRAINT unique_user_email_tracking UNIQUE (user_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_trial_email_tracking_user_id 
    ON trial_email_tracking(user_id);

CREATE INDEX IF NOT EXISTS idx_trial_email_tracking_trial_ends 
    ON trial_email_tracking(trial_ends_at);

CREATE INDEX IF NOT EXISTS idx_trial_email_tracking_pending_emails 
    ON trial_email_tracking(trial_ends_at) 
    WHERE NOT day6_email_sent;

-- Enable RLS
ALTER TABLE trial_email_tracking ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Only service role can read/write (edge functions use service role)
CREATE POLICY "Service role full access"
    ON trial_email_tracking
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Function to auto-create tracking record when trial subscription is created
CREATE OR REPLACE FUNCTION create_trial_email_tracking()
RETURNS TRIGGER AS $$
DECLARE
    v_user_email TEXT;
    v_user_name TEXT;
BEGIN
    -- Only create tracking for trial subscriptions
    IF NEW.status = 'trial' THEN
        -- Get user email and name
        SELECT 
            COALESCE(au.email, ''),
            COALESCE(au.raw_user_meta_data->>'full_name', SPLIT_PART(au.email, '@', 1))
        INTO v_user_email, v_user_name
        FROM auth.users au
        WHERE au.id = NEW.user_id;
        
        -- Insert tracking record (ignore if exists)
        INSERT INTO trial_email_tracking (
            user_id,
            subscription_id,
            trial_started_at,
            trial_ends_at,
            user_email,
            user_name,
            welcome_email_sent,
            welcome_email_sent_at
        )
        VALUES (
            NEW.user_id,
            NEW.id,
            COALESCE(NEW.trial_started_at, NEW.created_at),
            COALESCE(NEW.trial_ends_at, NEW.expires_at),
            v_user_email,
            v_user_name,
            TRUE,  -- Welcome email is sent on registration
            NOW()
        )
        ON CONFLICT (user_id) DO UPDATE SET
            subscription_id = EXCLUDED.subscription_id,
            trial_ends_at = EXCLUDED.trial_ends_at,
            updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_create_trial_email_tracking ON subscriptions;
CREATE TRIGGER trigger_create_trial_email_tracking
    AFTER INSERT ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION create_trial_email_tracking();

-- Function to update tracking when user converts to paid
CREATE OR REPLACE FUNCTION update_trial_tracking_on_conversion()
RETURNS TRIGGER AS $$
BEGIN
    -- When status changes from trial to active (paid)
    IF OLD.status = 'trial' AND NEW.status = 'active' THEN
        UPDATE trial_email_tracking
        SET 
            converted_to_paid = TRUE,
            converted_at = NOW(),
            updated_at = NOW()
        WHERE user_id = NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for conversion tracking
DROP TRIGGER IF EXISTS trigger_update_trial_tracking_conversion ON subscriptions;
CREATE TRIGGER trigger_update_trial_tracking_conversion
    AFTER UPDATE OF status ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_trial_tracking_on_conversion();

-- Backfill existing trial users
INSERT INTO trial_email_tracking (
    user_id,
    subscription_id,
    trial_started_at,
    trial_ends_at,
    user_email,
    user_name,
    welcome_email_sent,
    welcome_email_sent_at,
    -- Mark all past emails as sent for existing users to avoid spam
    day1_email_sent,
    day2_email_sent,
    day3_email_sent,
    day4_email_sent,
    day5_email_sent,
    day6_email_sent
)
SELECT 
    s.user_id,
    s.id,
    COALESCE(s.trial_started_at, s.created_at),
    COALESCE(s.trial_ends_at, s.expires_at),
    COALESCE(au.email, ''),
    COALESCE(au.raw_user_meta_data->>'full_name', SPLIT_PART(au.email, '@', 1)),
    TRUE,  -- Assume welcome email was sent
    s.created_at,
    -- For existing users, mark emails as sent based on days elapsed
    EXTRACT(DAY FROM NOW() - COALESCE(s.trial_started_at, s.created_at)) >= 1,
    EXTRACT(DAY FROM NOW() - COALESCE(s.trial_started_at, s.created_at)) >= 2,
    EXTRACT(DAY FROM NOW() - COALESCE(s.trial_started_at, s.created_at)) >= 3,
    EXTRACT(DAY FROM NOW() - COALESCE(s.trial_started_at, s.created_at)) >= 4,
    EXTRACT(DAY FROM NOW() - COALESCE(s.trial_started_at, s.created_at)) >= 5,
    EXTRACT(DAY FROM NOW() - COALESCE(s.trial_started_at, s.created_at)) >= 6
FROM subscriptions s
JOIN auth.users au ON au.id = s.user_id
WHERE s.status = 'trial'
ON CONFLICT (user_id) DO NOTHING;

-- Add comment for documentation
COMMENT ON TABLE trial_email_tracking IS 
'Tracks follow-up emails sent to trial users during their 7-day trial period. 
Used by the email campaign edge functions to prevent duplicate emails and track engagement.';

-- ============================================================================
-- CRON JOB SETUP
-- Run this AFTER deploying edge functions
-- ============================================================================
-- 
-- Step 1: Enable pg_cron extension (if not already enabled)
-- Go to Database → Extensions → Enable pg_cron
--
-- Step 2: Run this to schedule daily email processing at 9 AM Malaysia time (1 AM UTC)
/*
SELECT cron.schedule(
  'process-trial-followup-emails',
  '0 1 * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-trial-followup-emails',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
      body := '{}'::jsonb
    ) AS request_id;
  $$
);
*/
--
-- To check scheduled jobs:
-- SELECT * FROM cron.job;
--
-- To remove a scheduled job:
-- SELECT cron.unschedule('process-trial-followup-emails');
--
-- ============================================================================

COMMIT;
