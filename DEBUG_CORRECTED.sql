-- CORRECTED DEBUG: Check actual schema
-- Run these queries in Supabase SQL editor

-- 1. Check if carry_forward_items table exists
SELECT table_name FROM information_schema.tables 
WHERE table_name = 'carry_forward_items';

-- 2. Check if carry_forward_status column exists
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'consignment_claim_items' AND column_name = 'carry_forward_status';

-- 3. Check ALL columns in consignment_claim_items table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'consignment_claim_items'
ORDER BY ordinal_position;

-- 4. Check if any C/F items exist
SELECT id, product_name, status, quantity_available, created_at 
FROM carry_forward_items 
LIMIT 10;

-- 5. Check recent claim items (all columns)
SELECT * FROM consignment_claim_items
ORDER BY created_at DESC
LIMIT 1;
