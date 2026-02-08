-- ============================================================================
-- Allow Onboarding Users to Save Data
-- ============================================================================
-- Purpose: Allow users in onboarding to save data (test features)
-- After onboarding complete, subscription enforcement will apply
--
-- Changes:
-- 1. Update check_subscription_active() to also check onboarding status
-- 2. If user is in onboarding, allow access (return true)
-- 3. This allows users to test and save data during onboarding
-- ============================================================================

BEGIN;

-- ============================================================================
-- FUNCTION: Check if user is in onboarding
-- ============================================================================

CREATE OR REPLACE FUNCTION is_user_in_onboarding(user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_in_onboarding BOOLEAN;
BEGIN
  -- Check if user has seen onboarding (has_seen_onboarding = false means in onboarding)
  SELECT COALESCE(
    (SELECT has_seen_onboarding = FALSE 
     FROM user_onboarding_progress 
     WHERE user_id = user_uuid),
    TRUE  -- If no record exists, assume user is in onboarding (new user)
  ) INTO v_in_onboarding;
  
  RETURN v_in_onboarding;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Check if user has access (subscription OR onboarding)
-- ============================================================================
-- Updated to support:
-- 1. Onboarding users (allow access)
-- 2. Grace period (honor grace_until)
-- 3. Active/Trial subscriptions

CREATE OR REPLACE FUNCTION check_subscription_active(user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_has_access BOOLEAN;
  v_in_onboarding BOOLEAN;
BEGIN
  -- First check if user is in onboarding - if yes, allow access
  v_in_onboarding := is_user_in_onboarding(user_uuid);
  IF v_in_onboarding THEN
    RETURN TRUE; -- Allow access during onboarding
  END IF;
  
  -- If not in onboarding, check subscription (including grace period)
  SELECT EXISTS (
    SELECT 1
    FROM subscriptions
    WHERE user_id = user_uuid
      AND status IN ('active', 'trial', 'grace')
      AND (
        expires_at > NOW()
        OR (grace_until IS NOT NULL AND grace_until > NOW())
      )
  ) INTO v_has_access;

  RETURN v_has_access;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

