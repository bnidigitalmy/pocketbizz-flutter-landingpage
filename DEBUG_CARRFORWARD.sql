-- DEBUG: Check if C/F system is working
-- Run these queries in Supabase SQL editor

-- 1. Check if carry_forward_items table exists
SELECT table_name FROM information_schema.tables 
WHERE table_name = 'carry_forward_items';

-- 2. Check if carry_forward_status column exists in consignment_claim_items
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'consignment_claim_items' AND column_name = 'carry_forward_status';

-- 3. Check recent claim items with their C/F status
SELECT 
    id,
    claim_id,
    product_name,
    quantity_unsold,
    carry_forward_status,
    created_at
FROM consignment_claim_items
WHERE carry_forward_status IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- 4. Check if any C/F items exist
SELECT id, product_name, status, quantity_available, created_at 
FROM carry_forward_items 
LIMIT 10;

-- 5. If no C/F items, check if trigger exists
SELECT routine_name FROM information_schema.routines
WHERE routine_name = 'create_carry_forward_items';

-- 6. Check trigger definition
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trigger_create_carry_forward_items';
