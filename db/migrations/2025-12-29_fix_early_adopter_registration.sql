-- ============================================================================
-- Fix: Early Adopter Registration Not Working
-- Date: 2025-12-29
-- Issue: register_early_adopter() was silently failing due to EXCEPTION handler
-- ============================================================================

-- Fix ensure_trial_subscription to properly handle early adopter registration
-- Removes the problematic try-catch that was swallowing errors
CREATE OR REPLACE FUNCTION public.ensure_trial_subscription(user_uuid UUID)
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
  v_early_count INT;
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

  -- Get email directly (no try-catch needed for simple select)
  SELECT email INTO v_user_email FROM auth.users WHERE id = user_uuid;

  -- Check early adopter count first
  SELECT COUNT(*) INTO v_early_count FROM early_adopters WHERE is_active = TRUE;
  
  -- Register as early adopter if under 100
  IF v_early_count < 100 AND v_user_email IS NOT NULL THEN
    -- Direct insert instead of calling function (more reliable)
    INSERT INTO early_adopters (user_id, user_email, registered_at, is_active)
    VALUES (user_uuid, v_user_email, NOW(), TRUE)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
  
  -- Check if successfully registered as early adopter
  SELECT EXISTS (
    SELECT 1 FROM early_adopters 
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

-- ============================================================================
-- Fix existing users who should be early adopters but weren't registered
-- This fixes users who registered when early_adopter count was < 100
-- but didn't get added to early_adopters table due to the bug
-- ============================================================================

DO $$
DECLARE
  v_user RECORD;
  v_early_count INT;
  v_fixed_count INT := 0;
BEGIN
  -- Get current early adopter count
  SELECT COUNT(*) INTO v_early_count FROM early_adopters WHERE is_active = TRUE;
  
  RAISE NOTICE 'Current early adopter count: %', v_early_count;
  
  -- Find users with trial/active subscriptions who are NOT in early_adopters
  -- and were created when there was still room (we'll fill up to 100)
  FOR v_user IN 
    SELECT DISTINCT 
      s.user_id,
      u.email,
      s.created_at as subscription_created
    FROM subscriptions s
    JOIN auth.users u ON s.user_id = u.id
    WHERE s.user_id NOT IN (SELECT user_id FROM early_adopters)
      AND s.status IN ('trial', 'active', 'grace', 'pending_payment')
    ORDER BY s.created_at ASC  -- Oldest first (fairness)
    LIMIT (100 - v_early_count)  -- Only fill remaining slots
  LOOP
    -- Insert into early_adopters
    INSERT INTO early_adopters (user_id, user_email, registered_at, is_active)
    VALUES (v_user.user_id, v_user.email, v_user.subscription_created, TRUE)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Update their subscription
    UPDATE subscriptions 
    SET is_early_adopter = TRUE, 
        price_per_month = 29.0,
        updated_at = NOW()
    WHERE user_id = v_user.user_id 
      AND status IN ('trial', 'active', 'grace', 'pending_payment');
    
    v_fixed_count := v_fixed_count + 1;
    RAISE NOTICE 'Fixed early adopter: % (%)', v_user.email, v_user.user_id;
  END LOOP;
  
  RAISE NOTICE 'Total fixed: % users', v_fixed_count;
  RAISE NOTICE 'New early adopter count: %', (SELECT COUNT(*) FROM early_adopters WHERE is_active = TRUE);
END $$;

