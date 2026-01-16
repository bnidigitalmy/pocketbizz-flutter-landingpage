-- Migration: User Onboarding Progress
-- Date: 2025-01-16
-- Description: Store onboarding progress in database (not localStorage)
-- This ensures progress persists across devices and browser data clears

-- Create user_onboarding_progress table
CREATE TABLE IF NOT EXISTS user_onboarding_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Onboarding flow status
    has_seen_onboarding BOOLEAN DEFAULT FALSE,
    onboarding_completed_at TIMESTAMPTZ,
    
    -- Setup widget status
    setup_dismissed BOOLEAN DEFAULT FALSE,
    setup_dismissed_at TIMESTAMPTZ,
    
    -- Setup progress - Required tasks
    stock_count INTEGER DEFAULT 0,
    product_created BOOLEAN DEFAULT FALSE,
    production_recorded BOOLEAN DEFAULT FALSE,
    sale_recorded BOOLEAN DEFAULT FALSE,
    
    -- Setup progress - Optional tasks
    profile_completed BOOLEAN DEFAULT FALSE,
    vendor_added BOOLEAN DEFAULT FALSE,
    delivery_recorded BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one row per user
    CONSTRAINT unique_user_onboarding UNIQUE (user_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_onboarding_user_id ON user_onboarding_progress(user_id);

-- Enable RLS
ALTER TABLE user_onboarding_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access their own data
CREATE POLICY "Users can view own onboarding progress"
    ON user_onboarding_progress FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own onboarding progress"
    ON user_onboarding_progress FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own onboarding progress"
    ON user_onboarding_progress FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Function to auto-update updated_at
CREATE OR REPLACE FUNCTION update_onboarding_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_update_onboarding_updated_at ON user_onboarding_progress;
CREATE TRIGGER trigger_update_onboarding_updated_at
    BEFORE UPDATE ON user_onboarding_progress
    FOR EACH ROW
    EXECUTE FUNCTION update_onboarding_updated_at();

-- Function to get or create onboarding progress for current user
CREATE OR REPLACE FUNCTION get_or_create_onboarding_progress()
RETURNS user_onboarding_progress AS $$
DECLARE
    result user_onboarding_progress;
BEGIN
    -- Try to get existing record
    SELECT * INTO result FROM user_onboarding_progress WHERE user_id = auth.uid();
    
    -- If not exists, create one
    IF result IS NULL THEN
        INSERT INTO user_onboarding_progress (user_id)
        VALUES (auth.uid())
        RETURNING * INTO result;
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_or_create_onboarding_progress() TO authenticated;

COMMENT ON TABLE user_onboarding_progress IS 'Stores user onboarding and setup progress, persists across devices';
