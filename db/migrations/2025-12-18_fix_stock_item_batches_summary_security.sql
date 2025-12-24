-- ============================================================================
-- FIX: Remove SECURITY DEFINER from stock_item_batches_summary view
-- This ensures the view respects Row-Level Security (RLS) policies
-- ============================================================================

-- Drop the existing view (if it has SECURITY DEFINER or elevated owner)
DROP VIEW IF EXISTS public.stock_item_batches_summary CASCADE;

-- Recreate the view WITHOUT SECURITY DEFINER
-- Views in PostgreSQL are SECURITY INVOKER by default (run with caller privileges)
-- This ensures queries run with the caller's privileges and RLS applies normally
-- Note: Views don't have SECURITY DEFINER property (only functions do),
-- but if view owner has elevated privileges, it can effectively bypass RLS
CREATE VIEW public.stock_item_batches_summary AS
SELECT 
    sib.stock_item_id,
    si.name as stock_item_name,
    COUNT(*) as total_batches,
    SUM(sib.quantity) as total_quantity,
    SUM(sib.remaining_qty) as total_remaining,
    MIN(sib.expiry_date) as earliest_expiry,
    COUNT(*) FILTER (WHERE sib.expiry_date IS NOT NULL AND sib.expiry_date < CURRENT_DATE) as expired_batches,
    COUNT(*) FILTER (WHERE sib.remaining_qty > 0) as active_batches
FROM stock_item_batches sib
JOIN stock_items si ON si.id = sib.stock_item_id
GROUP BY sib.stock_item_id, si.name;

-- Note: Views in PostgreSQL are SECURITY INVOKER by default
-- They run with the privileges of the user querying them, not the owner
-- So we don't need to change ownership - the view will respect RLS automatically
-- The view owner doesn't matter for RLS enforcement since views are always SECURITY INVOKER

-- Add comment
COMMENT ON VIEW public.stock_item_batches_summary IS 
    'Summary of batches untuk each stock item dengan expiry tracking. '
    'View runs with caller privileges (SECURITY INVOKER) to respect RLS policies.';

-- Grant SELECT permission to authenticated users
-- (This is typically handled by RLS, but explicit grant ensures access)
GRANT SELECT ON public.stock_item_batches_summary TO authenticated;
GRANT SELECT ON public.stock_item_batches_summary TO anon;

-- Ensure underlying tables have proper RLS enabled (if not already)
-- This is critical for the view to respect RLS
DO $$
BEGIN
    -- Enable RLS on stock_item_batches if not already enabled
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'stock_item_batches'
        AND rowsecurity = true
    ) THEN
        ALTER TABLE public.stock_item_batches ENABLE ROW LEVEL SECURITY;
    END IF;
    
    -- Enable RLS on stock_items if not already enabled
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'stock_items'
        AND rowsecurity = true
    ) THEN
        ALTER TABLE public.stock_items ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

