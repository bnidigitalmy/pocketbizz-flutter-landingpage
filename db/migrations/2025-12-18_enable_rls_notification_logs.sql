-- ============================================================================
-- ENABLE RLS: notification_logs table
-- This ensures users can only access their own notification logs
-- ============================================================================

-- Enable Row Level Security
ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can view their own notification logs" ON public.notification_logs;
DROP POLICY IF EXISTS "Users can insert their own notification logs" ON public.notification_logs;
DROP POLICY IF EXISTS "Users can update their own notification logs" ON public.notification_logs;
DROP POLICY IF EXISTS "Users can delete their own notification logs" ON public.notification_logs;

-- SELECT Policy: Users can only view their own notification logs
CREATE POLICY "Users can view their own notification logs"
    ON public.notification_logs
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- INSERT Policy: Users can only insert notification logs for themselves
CREATE POLICY "Users can insert their own notification logs"
    ON public.notification_logs
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- UPDATE Policy: Users can only update their own notification logs
CREATE POLICY "Users can update their own notification logs"
    ON public.notification_logs
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- DELETE Policy: Users can only delete their own notification logs
CREATE POLICY "Users can delete their own notification logs"
    ON public.notification_logs
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- ============================================================================
-- FUNCTION: Insert notification log (with elevated privileges for system use)
-- This function allows system to insert notifications for any user
-- while maintaining security through validation
-- ============================================================================

CREATE OR REPLACE FUNCTION public.insert_notification_log(
    p_user_id UUID,
    p_channel TEXT,
    p_type TEXT,
    p_status TEXT DEFAULT 'sent',
    p_subject TEXT DEFAULT NULL,
    p_payload JSONB DEFAULT NULL,
    p_error TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
    v_current_user_id UUID;
BEGIN
    -- Get current user ID
    v_current_user_id := auth.uid();
    
    -- Validation: Allow insert if:
    -- 1. User inserting for themselves (normal case)
    -- 2. User is authenticated (system/admin can insert for others via this function)
    -- Note: This function runs with SECURITY DEFINER, so it bypasses RLS
    -- but we still validate that a user is authenticated
    
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to insert notification logs';
    END IF;
    
    -- Insert notification log
    INSERT INTO public.notification_logs (
        user_id,
        channel,
        type,
        status,
        subject,
        payload,
        error
    ) VALUES (
        p_user_id,
        p_channel,
        p_type,
        p_status,
        p_subject,
        p_payload,
        p_error
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.insert_notification_log IS 
    'Insert notification log with elevated privileges. '
    'Allows system to insert notifications for any user. '
    'Requires authenticated user to call this function.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.insert_notification_log TO authenticated;

-- Revoke broad privileges (rely on policies instead)
-- Note: This ensures only policies control access, not direct grants
REVOKE ALL ON public.notification_logs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_logs TO authenticated;

-- Index already exists on user_id (idx_notification_logs_user_id)
-- This index helps with policy performance

COMMENT ON TABLE public.notification_logs IS 
    'Notification logs for email/SMS/in-app audit. '
    'RLS enabled: users can only access their own logs. '
    'Use insert_notification_log() function for system inserts.';

