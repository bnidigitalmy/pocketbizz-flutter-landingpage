-- ============================================================================
-- Fix: New users not automatically getting Early Adopter
-- Date: 2025-12-30
--
-- Root cause:
-- - Signup trigger calls ensure_trial_subscription_for_user(NEW.id)
-- - That function previously used register_early_adopter() inside a try/catch
--   that could silently fail and force v_is_early := FALSE.
--
-- Fix:
-- - Update ensure_trial_subscription_for_user to directly insert into early_adopters
--   when active count < 100 (same approach as 2025-12-29 fix).
-- - Update ensure_trial_subscription() (no-args RPC) to delegate to the same logic.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.ensure_trial_subscription_for_user(user_uuid UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_id UUID;
  v_plan_id UUID;
  v_is_early BOOLEAN := FALSE;
  v_trial_ends_at TIMESTAMPTZ;
  v_new_id UUID;
  v_user_email TEXT;
  v_early_count INT := 0;
BEGIN
  -- If user already has active access, return it.
  SELECT id INTO v_existing_id
  FROM public.subscriptions
  WHERE user_id = user_uuid
    AND status IN ('active', 'trial', 'grace')
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;

  -- Trial once in a lifetime.
  IF EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE user_id = user_uuid
      AND has_ever_had_trial = TRUE
  ) THEN
    RETURN NULL;
  END IF;

  -- Find 1-month plan to attach to trial.
  SELECT id INTO v_plan_id
  FROM public.subscription_plans
  WHERE duration_months = 1
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'No 1-month subscription plan found';
  END IF;

  -- Get email (best-effort; do not block trial)
  BEGIN
    SELECT email INTO v_user_email FROM auth.users WHERE id = user_uuid;
  EXCEPTION WHEN OTHERS THEN
    v_user_email := NULL;
  END;

  -- Early adopter (reliable): direct insert if under 100
  SELECT COUNT(*) INTO v_early_count FROM public.early_adopters WHERE is_active = TRUE;

  IF v_early_count < 100 AND v_user_email IS NOT NULL THEN
    INSERT INTO public.early_adopters (user_id, user_email, registered_at, is_active)
    VALUES (user_uuid, v_user_email, NOW(), TRUE)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.early_adopters
    WHERE user_id = user_uuid AND is_active = TRUE
  ) INTO v_is_early;

  v_trial_ends_at := NOW() + INTERVAL '7 days';

  INSERT INTO public.subscriptions (
    user_id,
    plan_id,
    price_per_month,
    total_amount,
    discount_applied,
    is_early_adopter,
    status,
    trial_started_at,
    trial_ends_at,
    expires_at,
    has_ever_had_trial,
    auto_renew,
    created_at,
    updated_at
  ) VALUES (
    user_uuid,
    v_plan_id,
    CASE WHEN v_is_early THEN 29.0 ELSE 39.0 END,
    0.0,
    0.0,
    v_is_early,
    'trial',
    NOW(),
    v_trial_ends_at,
    v_trial_ends_at,
    TRUE,
    FALSE,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

-- Keep the no-arg RPC as a simple wrapper used by clients.
CREATE OR REPLACE FUNCTION public.ensure_trial_subscription()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN public.ensure_trial_subscription_for_user(v_user_id);
END;
$$;

COMMIT;


