-- ============================================================================
-- Disable Free Trial - Require Payment on Registration
-- ============================================================================
-- Purpose: Disable automatic free trial creation for new users.
-- New users must subscribe immediately after registration.
-- This ensures users are serious about using the platform.
--
-- Changes:
-- 1. Remove trial creation from handle_new_user trigger
-- 2. Keep ensure_trial_subscription_for_user function (for manual use if needed)
-- 3. Users without subscription will be redirected to subscription page
-- ============================================================================

BEGIN;

-- Update handle_new_user to REMOVE trial creation
-- Users will need to subscribe immediately after registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_phone TEXT;
BEGIN
  user_phone := NEW.raw_user_meta_data->>'phone';

  -- 1) Create/Update profile row (best-effort, never block signup)
  BEGIN
    INSERT INTO public.users (id, email, full_name, phone)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
      user_phone
    )
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email,
      full_name = COALESCE(EXCLUDED.full_name, users.full_name),
      phone = COALESCE(EXCLUDED.phone, users.phone),
      updated_at = NOW();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to insert user profile for user %: %', NEW.id, SQLERRM;
  END;

  -- 2) TRIAL CREATION DISABLED - User must subscribe immediately
  -- Removed: PERFORM public.ensure_trial_subscription_for_user(NEW.id);
  -- Users will be redirected to subscription page after registration

  -- 3) Try to sync auth.users.phone (optional)
  IF user_phone IS NOT NULL AND user_phone != '' THEN
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE phone = user_phone
          AND id != NEW.id
      ) THEN
        UPDATE auth.users
        SET phone = user_phone,
            updated_at = NOW()
        WHERE id = NEW.id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to update auth.users.phone for user %: %', NEW.id, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

